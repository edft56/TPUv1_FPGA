`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module compute_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input instruction_i,
                    input [8:0] H_DIM_i,
                    input [8:0] W_DIM_i,
                    input compute_weights_rdy_i,
                    input compute_weights_buffered_i,
                    input [11:0] unified_buffer_start_addr_rd_i,

                    output logic [11:0] unified_buffer_addr_rd_o,
                    output logic load_activations_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [6:0] accumulator_addr_wr_o,
                    output logic [6:0] accumulator_addr_rd_o,
                    output logic [MUL_SIZE-1:0] accum_addr_mask_o,
                    output logic accumulator_add_o,
                    output logic next_weight_tile_o,
                    output logic done_o
                    );


    enum logic [2:0] {STALL, NO_OUTPUT, PARTIAL_OUTPUT, FULL_OUTPUT, REVERSE_PARTIAL} accum_output_state;


    logic [ 9:0] accum_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    logic [ 3:0] weight_tiles_x_consumed_q;
    logic [ 3:0] weight_tiles_y_consumed_q;
    logic [ 3:0] weight_tiles_x_consumed;
    logic [ 3:0] weight_tiles_y_consumed;


    logic [ 9:0] next_accum_cntr;
    logic        done;
    //logic        next_weight_tile;
    logic        done_weight_tiles_y;
    logic        done_weight_tiles_x;
    logic [11:0] unified_buffer_addr_rd;

    initial accum_output_state = NO_OUTPUT;
    
    initial accum_cntr_q = 0;
    initial weight_tiles_x_consumed_q = 0;
    initial weight_tiles_y_consumed_q = 0;
    initial accumulator_add_o = 0;
    initial next_accum_cntr = 0;

    always_comb begin
        next_accum_cntr = (next_weight_tile_o) ? '0 : accum_cntr_q + 1;

        done        = done_weight_tiles_x;
    end
    

    always_ff @( posedge clk_i ) begin

        accumulator_add_o       <= (done_weight_tiles_y) ? '0 : ( (next_weight_tile_o) ? '1 : accumulator_add_o);
        read_accumulator_o      <= accum_output_state != NO_OUTPUT & (done_weight_tiles_y) ? '0 : ( (next_weight_tile_o) ? '1 : read_accumulator_o);
        
        case (accum_output_state)
            STALL: begin
                if(MAC_compute_i) begin
                    accum_output_state <= NO_OUTPUT;
                end
            end
            NO_OUTPUT: begin
                accumulator_addr_rd_o   <= '0;
                accumulator_addr_wr_o   <= '0;
                accum_addr_mask_o       <= '0;
                write_accumulator_o     <= '0;

                accum_cntr_q <= accum_cntr_q + 1;

                if(accum_cntr_q[4:0] == (MUL_SIZE-1)) begin
                    accum_cntr_q          <= '0;
                    accum_output_state    <= PARTIAL_OUTPUT;
                    accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5);
                end
            end
            PARTIAL_OUTPUT: begin
                write_accumulator_o     <= 1'b1;

                accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_accum_cntr;
                accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + accum_cntr_q;
                accum_addr_mask_o       <= signed'(signed'(32'h80000000)>>>accum_cntr_q);

                accum_cntr_q <= accum_cntr_q + 1;

                if (accum_cntr_q == (MUL_SIZE-1)) begin
                    accum_output_state <= FULL_OUTPUT;
                end
            end
            FULL_OUTPUT: begin
                write_accumulator_o     <= 1'b1;

                accum_addr_mask_o       <= '1;
                accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_accum_cntr;
                accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + accum_cntr_q;

                accum_cntr_q <= accum_cntr_q + 1;

                if(compute_weights_rdy_i != '1 | done_compute_i) begin
                    accum_output_state <= REVERSE_PARTIAL;
                end
            end
            REVERSE_PARTIAL: begin
                write_accumulator_o     <= 1'b1;

                accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_accum_cntr;
                accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + accum_cntr_q;
                accum_addr_mask_o       <= (32'h7FFFFFFF)>>rev_partial_cntr_q;

                rev_partial_cntr_q      <= rev_partial_cntr_q + 1;
                accum_cntr_q            <= accum_cntr_q + 1;
            end
            default: begin

            end
        endcase


        // if(next_weight_tile_o) begin
        //     if (compute_weights_buffered_i) begin
        //         compute_state           <= LOAD_ACTIVATIONS;
        //     end
        //     else compute_state          <= STALL;
            
        //     compute_cntr_q          <= '0;
        //     rev_partial_cntr_q      <= '0;

        //     compute_output_state    <= NO_OUTPUT;
        // end
        

    end
endmodule