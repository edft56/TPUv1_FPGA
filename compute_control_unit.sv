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

    enum logic [1:0] {STALL, LOAD_ACTIVATIONS, COMPUTE} compute_state;

    enum logic [1:0] {NO_OUTPUT, PARTIAL_OUTPUT, FULL_OUTPUT, REVERSE_PARTIAL} compute_output_state;


    logic [ 9:0] compute_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    logic [ 3:0] weight_tiles_x_consumed_q;
    logic [ 3:0] weight_tiles_y_consumed_q;
    logic [ 3:0] weight_tiles_x_consumed;
    logic [ 3:0] weight_tiles_y_consumed;


    logic [ 9:0] next_compute_cntr;
    logic        done;
    //logic        next_weight_tile;
    logic        done_weight_tiles_y;
    logic        done_weight_tiles_x;
    logic [11:0] unified_buffer_addr_rd;

    initial compute_state = STALL;
    initial compute_output_state = NO_OUTPUT;
    
    initial compute_cntr_q = 0;
    initial weight_tiles_x_consumed_q = 0;
    initial weight_tiles_y_consumed_q = 0;
    initial accumulator_add_o = 0;
    initial next_compute_cntr = 0;

    always_comb begin
        next_weight_tile_o  = rev_partial_cntr_q == MUL_SIZE-1;

        done_weight_tiles_y = (weight_tiles_y_consumed_q == 4'(H_DIM_i>>5)) & next_weight_tile_o;
        done_weight_tiles_x = (weight_tiles_x_consumed_q == 4'(W_DIM_i>>5)) & done_weight_tiles_y;

        weight_tiles_y_consumed = (done_weight_tiles_y) ? '0 : ( next_weight_tile_o    ? weight_tiles_y_consumed_q + 1 : weight_tiles_y_consumed_q );
        weight_tiles_x_consumed = (done_weight_tiles_x) ? '0 : ( done_weight_tiles_y ? weight_tiles_x_consumed_q + 1 : weight_tiles_x_consumed_q );

        next_compute_cntr = (next_weight_tile_o) ? '0 : compute_cntr_q + 1;

        if(next_weight_tile_o) unified_buffer_addr_rd = unified_buffer_start_addr_rd_i + (weight_tiles_y_consumed)*(((H_DIM_i>>5)+1)<<5);
        else if (compute_state == LOAD_ACTIVATIONS | compute_state == COMPUTE) unified_buffer_addr_rd = unified_buffer_addr_rd_o + 1;
        else unified_buffer_addr_rd = unified_buffer_start_addr_rd_i + weight_tiles_y_consumed_q*(((H_DIM_i>>5)+1)<<5);

        //unified_buffer_addr_rd = (compute_state == LOAD_ACTIVATIONS | compute_state == COMPUTE) ? unified_buffer_addr_rd_o + 1 : unified_buffer_start_addr_rd_i + weight_tiles_y_consumed_q*(((H_DIM_i>>5)+1)<<5);

        done        = done_weight_tiles_x;
    end
    

    always_ff @( posedge clk_i ) begin
        done_o                   <= 1'b0;

        //assume tiles are written to unified buffer in the required order. assume read is disabled during reverse partial state.
        unified_buffer_addr_rd_o <= unified_buffer_addr_rd;

        accumulator_add_o       <= (done_weight_tiles_y) ? '0 : ( (next_weight_tile_o) ? '1 : accumulator_add_o);
        read_accumulator_o      <= compute_output_state != NO_OUTPUT & (done_weight_tiles_y) ? '0 : ( (next_weight_tile_o) ? '1 : read_accumulator_o);

        weight_tiles_y_consumed_q <= weight_tiles_y_consumed;
        weight_tiles_x_consumed_q <= weight_tiles_x_consumed;

        case(compute_state)
            STALL: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                //read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                write_accumulator_o     <= 1'b0;
                

                if (instruction_i & compute_weights_rdy_i) begin
                    load_activations_o  <= 1'b1;
                    compute_state       <= LOAD_ACTIVATIONS;
                end
            end
            LOAD_ACTIVATIONS: begin
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b1;
                //read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                write_accumulator_o     <= 1'b0;

                //if (activations_rdy_i == 1'b1) begin
                    compute_state <= COMPUTE;
                    //MAC_compute_o           <= 1'b1;
                //end
            end
            COMPUTE: begin
                //load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b0;
                MAC_compute_o           <= 1'b1;

                
                case (compute_output_state)
                    NO_OUTPUT: begin
                        load_activations_o      <= 1'b1;
                        accumulator_addr_rd_o   <= '0;
                        accumulator_addr_wr_o   <= '0;
                        accum_addr_mask_o       <= '0;
                        write_accumulator_o     <= '0;

                        compute_cntr_q <= compute_cntr_q + 1;

                        if(compute_cntr_q[4:0] == (MUL_SIZE-1)) begin
                            compute_cntr_q          <= '0;
                            compute_output_state    <= PARTIAL_OUTPUT;
                            accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5);
                        end
                    end
                    PARTIAL_OUTPUT: begin
                        load_activations_o      <= 1'b1;
                        write_accumulator_o     <= 1'b1;

                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_compute_cntr;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;
                        accum_addr_mask_o       <= signed'(signed'(32'h80000000)>>>compute_cntr_q);

                        compute_cntr_q <= compute_cntr_q + 1;

                        if (compute_cntr_q >= (MUL_SIZE-2)) load_activations_o   <= 1'b0;

                        if (compute_cntr_q == (MUL_SIZE-1)) begin
                            compute_output_state <= FULL_OUTPUT;
                        end
                    end
                    FULL_OUTPUT: begin
                        load_activations_o      <= 1'b0;
                        write_accumulator_o     <= 1'b1;

                        accum_addr_mask_o       <= '1;
                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_compute_cntr;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;

                        compute_cntr_q <= compute_cntr_q + 1;

                        if(compute_cntr_q == H_DIM_i) begin
                            compute_output_state <= REVERSE_PARTIAL;
                            load_activations_o   <= 1'b0;
                        end
                    end
                    REVERSE_PARTIAL: begin
                        load_activations_o      <= 1'b0;
                        write_accumulator_o     <= 1'b1;

                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + next_compute_cntr;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;
                        accum_addr_mask_o       <= (32'h7FFFFFFF)>>rev_partial_cntr_q;

                        rev_partial_cntr_q      <= rev_partial_cntr_q + 1;
                        compute_cntr_q          <= compute_cntr_q + 1;
                    end
                endcase

                if(done) begin
                    done_o                  <= 1'b1;
                    compute_state           <= STALL;
                end
                if(next_weight_tile_o) begin
                    if (compute_weights_buffered_i) begin
                        compute_state           <= LOAD_ACTIVATIONS;
                        load_activations_o      <= 1'b1;
                    end
                    else compute_state          <= STALL;
                    
                    compute_cntr_q          <= '0;
                    rev_partial_cntr_q      <= '0;
                    //MAC_compute_o           <= 1'b0;
                    //unified_buffer_cntr_q <= '0;

                    compute_output_state    <= NO_OUTPUT;
                end
                
            end
            default: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
            end

        endcase
        

    end
endmodule

