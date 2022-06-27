`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module weight_control_unit
                        import tpu_package::*;    
                        (   
                            input clk_i,rst_i,
                            input decoded_instr_t instruction_i,
                            input weight_fifo_valid_output,
                            input next_weight_tile_i,
                            input iq_empty_i,

                            output logic read_instruction_o,
                            output logic compute_weights_rdy_o,
                            output logic compute_weights_buffered_o,
                            output logic [MUL_SIZE-1:0] load_weights_o
                        );


    enum logic [2:0] {RESET, STALL, LOAD_WEIGHTS, DOUBLE_BUFFER, FULL} weight_state;

    logic [ 4:0] load_weights_cntr_q;
    logic        next_tile_flag_q;
    logic [ 4:0] current_weight_tile_q;
    logic [7:0]  U_dim_q;                
    logic [7:0]  ITER_dim_q;    
    logic done_q;   

    logic [ 4:0] max_tiles;
    logic done;
    logic next_tile;

    initial weight_state        = RESET;
    initial read_instruction_o  = '0;
    initial next_tile_flag_q    = '0;

    always_comb begin
        next_tile                   = load_weights_cntr_q == MUL_SIZE-1;
        max_tiles                   = (U_dim_q >> 5) * (ITER_dim_q >> 5);

        done                        = (current_weight_tile_q + 1 == max_tiles) & load_weights_cntr_q + 1 == MUL_SIZE-1;

        compute_weights_rdy_o       = ( (weight_state == DOUBLE_BUFFER | weight_state == FULL) |
                                        (weight_state == DOUBLE_BUFFER & next_weight_tile_i)   |
                                        (weight_state == LOAD_WEIGHTS) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) 
                                        ? '1 : '0;

        compute_weights_buffered_o  = ( (weight_state == FULL) | (weight_state == DOUBLE_BUFFER) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) ? '1 : '0;
    end
    

    always_ff @( posedge clk_i ) begin
        current_weight_tile_q       <= (done_q) ? '0 : ( (next_tile & weight_state != RESET) ? current_weight_tile_q + 1 : current_weight_tile_q );
        done_q                      <= done;
        read_instruction_o          <= (!iq_empty_i) & (current_weight_tile_q + 1 == max_tiles) & (load_weights_cntr_q + 1 == MUL_SIZE-1);

        case(weight_state)
            RESET: begin
                load_weights_cntr_q     <= '0;
                load_weights_o          <= '0;
                next_tile_flag_q        <= '0;
                read_instruction_o      <= (!iq_empty_i) ? '1 : '0;
                current_weight_tile_q   <= '0;

                if (instruction_i.MAC_op[1]) begin
                    weight_state <= LOAD_WEIGHTS;
                    U_dim_q                 <= instruction_i.U_dim;
                    ITER_dim_q              <= instruction_i.ITER_dim;
                    read_instruction_o      <= '0;
                end
            end
            STALL: begin
                load_weights_o                  <= '0;

                // if (MAC_op_i[1]) begin
                //     weight_state                <= LOAD_WEIGHTS;
                // end
            end
            LOAD_WEIGHTS: begin
                load_weights_o                  <= '1;

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;


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

            end
            default: begin
            end
        endcase
        
        if(done_q) begin
            if(instruction_i.MAC_op[1]) begin
                U_dim_q                 <= instruction_i.U_dim;
                ITER_dim_q              <= instruction_i.ITER_dim;
            end
            else begin
                weight_state            <= RESET;
            end
        end
    end
endmodule
