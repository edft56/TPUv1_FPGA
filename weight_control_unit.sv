`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module weight_control_unit
                        import tpu_package::*;    
                        (   
                            input clk_i,rst_i,
                            input instruction_i,
                            input weight_fifo_valid_output,
                            input logic [8:0] H_DIM_i,
                            input logic [8:0] W_DIM_i,
                            input fifo_full_i,

                            output logic compute_weights_rdy_o,
                            output logic compute_weights_buffered_o,
                            output logic load_weights_o,
                            output logic done_o
                        );


    enum logic [2:0] {STALL, LOAD_WEIGHT_FIFO, LOAD_WEIGHTS, DOUBLE_BUFFER, FULL} weight_state;

    logic [ 4:0] load_weights_cntr_q;

    initial weight_state = STALL;


    always_comb begin
        
    end
    

    always_ff @( posedge clk_i ) begin
        
        case(weight_state)
        
            STALL: begin
                load_weights_o                  <= '0;
                compute_weights_rdy             <= '0;
                compute_weights_buffered_o      <= '0;

                if (instruction_i) begin
                    weight_state                <= LOAD_WEIGHT_FIFO;
                end
            end
            LOAD_WEIGHT_FIFO: begin //should be separate control for fifo
                compute_weights_rdy             <= '0;
                compute_weights_buffered_o      <= '0;

                if (fifo_full_i) begin
                    load_weights_o              <= 1'b1;
                    compute_state               <= LOAD_WEIGHTS;
                end
            end
            LOAD_WEIGHTS: begin
                load_weights_o                  <= 1'b1;
                compute_weights_rdy             <= '0;
                compute_weights_buffered_o      <= '0;

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

                if (load_weights_cntr_q == MUL_SIZE-1) begin
                    weight_state                <= (weight_fifo_valid_output) ? DOUBLE_BUFFER : weight_state;
                    load_weights_o              <= (weight_fifo_valid_output) ? '0 : load_weights_o;

                    compute_state               <= (weight_fifo_valid_output) ? LOAD_ACTIVATIONS : compute_state;
                    load_activations_o          <= (weight_fifo_valid_output) ? '1 : load_activations_o;
                    compute_weights_rdy         <= (weight_fifo_valid_output) ? '1 : compute_weights_rdy;
                end
            end
            DOUBLE_BUFFER: begin
                load_weights_o                  <= 1'b1;
                compute_weights_rdy             <= '1;
                compute_weights_buffered_o      <= '0;

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

                if(next_weight_tile_i) begin
                    compute_weights_rdy         <= '0;
                    weight_state                <= LOAD_WEIGHTS;
                end

                if (load_weights_cntr_q == MUL_SIZE-1) begin
                    weight_state                <= (weight_fifo_valid_output) ? FULL : weight_state;
                    load_weights_o              <= (weight_fifo_valid_output) ? '0 : load_weights_o;
                    compute_weights_buffered_o  <= '1;
                end
            end
            FULL: begin
                compute_weights_rdy             <= '1;
                compute_weights_buffered_o      <= '1;
            end

        endcase
        

    end
endmodule

