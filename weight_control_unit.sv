`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module weight_control_unit
                        import tpu_package::*;    
                        (   
                            input clk_i,rst_i,
                            input [2:0] MAC_op_i,
                            input weight_fifo_valid_output,
                            input next_weight_tile_i,
                            input done_i,

                            output logic compute_weights_rdy_o,
                            output logic compute_weights_buffered_o,
                            output logic [MUL_SIZE-1:0] load_weights_o
                        );


    enum logic [2:0] {RESET, STALL, LOAD_WEIGHTS, DOUBLE_BUFFER, FULL} weight_state;

    logic [ 4:0] load_weights_cntr_q;
    logic        next_tile_flag_q;

    initial weight_state        = RESET;
    initial next_tile_flag_q    = '0;

    always_comb begin
        compute_weights_rdy_o       = ( (weight_state == DOUBLE_BUFFER | weight_state == FULL) |
                                        (weight_state == DOUBLE_BUFFER & next_weight_tile_i)   |
                                        (weight_state == LOAD_WEIGHTS) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) 
                                        ? '1 : '0;

        compute_weights_buffered_o  = ( (weight_state == FULL) | (weight_state == DOUBLE_BUFFER) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) ? '1 : '0;
    end
    

    always_ff @( posedge clk_i ) begin
        
        case(weight_state)
            RESET: begin
                load_weights_cntr_q <= '0;
                load_weights_o      <= '0;
                next_tile_flag_q    <= '0;

                if (MAC_op_i[1]) begin
                    weight_state <= STALL;
                end
            end
            STALL: begin
                load_weights_o                  <= '0;

                if (MAC_op_i[1]) begin
                    weight_state                <= LOAD_WEIGHTS;
                end
            end
            LOAD_WEIGHTS: begin
                load_weights_o                  <= '1;

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

                if(done_i) begin
                    weight_state                <= STALL;
                end

                if (load_weights_cntr_q == MUL_SIZE-1) begin
                    weight_state                <= (weight_fifo_valid_output) ? DOUBLE_BUFFER : weight_state;
                    load_weights_o                  <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
                end
            end
            DOUBLE_BUFFER: begin
                load_weights_o                  <= signed'(signed'(32'h80000000)>>>load_weights_cntr_q + 1);

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

                if(next_weight_tile_i) begin
                    weight_state                <= LOAD_WEIGHTS;
                end

                if(done_i & !MAC_op_i[1]) begin
                    weight_state                <= RESET;
                end

                if (load_weights_cntr_q == MUL_SIZE-1) begin
                    weight_state                <= (weight_fifo_valid_output) ? FULL : weight_state;
                    load_weights_o              <= (weight_fifo_valid_output) ? '0 : load_weights_o;
                end
            end
            FULL: begin
                load_weights_o                  <= '0;

                if(next_weight_tile_i) begin
                    next_tile_flag_q            <= 1;
                    load_weights_cntr_q         <= load_weights_cntr_q + 1;
                end

                if(next_tile_flag_q) begin
                    load_weights_cntr_q         <= load_weights_cntr_q + 1;

                    if (load_weights_cntr_q == MUL_SIZE-1) begin
                        next_tile_flag_q        <= 0;
                        weight_state            <= DOUBLE_BUFFER;
                        load_weights_o                  <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
                    end
                end

                if(done_i) begin
                    weight_state                <= STALL;
                end
            end
            default: begin
            end

        endcase
        

    end
endmodule
