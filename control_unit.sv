`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input instruction_i,
                    input activations_rdy_i,
                    input weight_fifo_valid_output,
                    input logic [6:0] accumulator_start_addr_wr_i,
                    input logic [8:0] H_DIM_i,
                    input logic [8:0] W_DIM_i,
                    input fifo_full_i,

                    output logic load_weights_o,
                    output logic load_activations_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [6:0] accumulator_addr_wr_o,
                    output logic [6:0] accumulator_addr_rd_o,
                    output logic [MUL_SIZE-1:0] accum_addr_mask_o,
                    output logic accumulator_add_o,
                    output logic done_o
                    );

    enum logic [2:0] {STALL, LOAD_WEIGHT_FIFO, LOAD_WEIGHTS, LOAD_ACTIVATIONS, COMPUTE} state;

    enum logic [1:0] {NO_OUTPUT, PARTIAL_OUTPUT, FULL_OUTPUT, REVERSE_PARTIAL} compute_output_state;

    logic [ 4:0] load_weights_cntr_q;
    logic [ 9:0] compute_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    logic [ 3:0] weight_tiles_x_consumed_q;
    logic [ 3:0] weight_tiles_y_consumed_q;

    logic        done;
    logic        next_weight_tile;
    logic        done_weight_tiles_y;
    logic        done_weight_tiles_x;

    initial compute_cntr_q = 0;
    initial state = STALL;
    initial compute_output_state = NO_OUTPUT;
    initial weight_tiles_x_consumed_q = 0;
    initial weight_tiles_y_consumed_q = 0;
    initial accumulator_add_o = 0;

    always_comb begin
        next_weight_tile   = rev_partial_cntr_q == MUL_SIZE-1;

        done_weight_tiles_y = (weight_tiles_y_consumed_q == 4'(W_DIM_i>>5)) & next_weight_tile;
        done_weight_tiles_x = (weight_tiles_x_consumed_q == 4'(W_DIM_i>>5)) & done_weight_tiles_y;

        done        = done_weight_tiles_x;
    end
    

    always_ff @( posedge clk_i ) begin
        done_o                  <= 1'b0;
        case(state)
            STALL: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                write_accumulator_o     <= 1'b0;
                

                if (instruction_i) begin
                    state <= LOAD_WEIGHT_FIFO;
                end
            end
            LOAD_WEIGHT_FIFO: begin
                if (fifo_full_i) begin
                    load_weights_o          <= 1'b1;
                    state <= LOAD_WEIGHTS;
                end
            end
            LOAD_WEIGHTS: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b1;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                write_accumulator_o     <= 1'b0;

                load_weights_cntr_q <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;
                if (load_weights_cntr_q == MUL_SIZE-1) begin
                    state           <= (weight_fifo_valid_output) ? LOAD_ACTIVATIONS : state;
                    load_weights_o  <= (weight_fifo_valid_output) ? 1'b0 : load_weights_o;
                end
            end
            LOAD_ACTIVATIONS: begin
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                write_accumulator_o     <= 1'b0;

                if (activations_rdy_i == 1'b1) begin
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b0;
                load_weights_o          <= 1'b0;
                MAC_compute_o           <= 1'b1;
                accumulator_add_o       <= (done_weight_tiles_y) ? '0 : ( (next_weight_tile) ? '1 : accumulator_add_o);
                read_accumulator_o      <= (done_weight_tiles_y) ? '0 : ( (next_weight_tile) ? '1 : read_accumulator_o);

                

                weight_tiles_y_consumed_q <= (done_weight_tiles_y) ? '0 : ( next_weight_tile    ? weight_tiles_y_consumed_q + 1 : weight_tiles_y_consumed_q );
                weight_tiles_x_consumed_q <= (done_weight_tiles_x) ? '0 : ( done_weight_tiles_y ? weight_tiles_x_consumed_q + 1 : weight_tiles_x_consumed_q );
                
                case (compute_output_state)
                    NO_OUTPUT: begin
                        accumulator_addr_rd_o   <= '0;
                        accumulator_addr_wr_o   <= '0;
                        accum_addr_mask_o       <= '0;
                        write_accumulator_o     <= '0;

                        compute_cntr_q <= compute_cntr_q + 1;

                        if(compute_cntr_q[4:0] == (MUL_SIZE-1)) begin
                            compute_cntr_q <= '0;
                            compute_output_state <= PARTIAL_OUTPUT;
                            accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q + 1;
                        end
                    end
                    PARTIAL_OUTPUT: begin
                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q + 1;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;
                        accum_addr_mask_o       <= signed'(signed'(32'h80000000)>>>compute_cntr_q);
                        write_accumulator_o     <= 1'b1;

                        compute_cntr_q <= compute_cntr_q + 1;

                        if (compute_cntr_q == (MUL_SIZE-1)) begin
                            compute_output_state <= FULL_OUTPUT;
                        end
                    end
                    FULL_OUTPUT: begin
                        accum_addr_mask_o       <= '1;
                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q + 1;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;
                        write_accumulator_o     <= 1'b1;

                        compute_cntr_q <= compute_cntr_q + 1;

                        if(compute_cntr_q == H_DIM_i) begin
                            compute_output_state <= REVERSE_PARTIAL;
                        end
                    end
                    REVERSE_PARTIAL: begin
                        accumulator_addr_rd_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q + 1;
                        accumulator_addr_wr_o   <= weight_tiles_x_consumed_q*(((H_DIM_i>>5)+1)<<5) + compute_cntr_q;
                        accum_addr_mask_o       <= (32'h7FFFFFFF)>>rev_partial_cntr_q;
                        write_accumulator_o     <= 1'b1;

                        rev_partial_cntr_q <= rev_partial_cntr_q + 1;
                        compute_cntr_q <= compute_cntr_q + 1;
                    end
                endcase

                if(done) begin
                    done_o <= 1'b1;
                    state <= STALL;
                end
                if(next_weight_tile) begin
                    load_weights_o          <= 1'b1;
                    state <= LOAD_WEIGHTS;
                    compute_cntr_q <= '0;
                    rev_partial_cntr_q <= '0;

                    compute_output_state <= NO_OUTPUT;
                end
                
            end
            default: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
            end

        endcase
        

    end
endmodule

