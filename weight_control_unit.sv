`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module weight_control_unit
                        import tpu_package::*;    
                        (   
                            input clk_i,rstN_i,
                            input decoded_instr_t instruction_i,
                            input weight_fifo_valid_output,
                            input next_weight_tile_i,
                            input iq_empty_i,

                            output logic read_instruction_o,
                            output logic compute_weights_rdy_o,
                            output logic compute_weights_buffered_o,
                            output logic [MUL_SIZE-1:0] load_weights_o
                        );

    typedef enum logic [4:0] {
                                RESET           = 5'b00001, 
                                STALL           = 5'b00010, 
                                LOAD_WEIGHTS    = 5'b00100, 
                                DOUBLE_BUFFER   = 5'b01000, 
                                FULL            = 5'b10000
                                } weight_states_t;

    weight_states_t weight_state, next_weight_state;

    logic [ 4:0] load_weights_cntr_q;
    logic        next_tile_flag_q;
    logic [ 4:0] current_weight_tile_q;
    logic [ 4:0] max_tiles_q;

    logic done;
    logic next_tile;

    initial weight_state        = RESET;
    initial read_instruction_o  = '0;
    initial next_tile_flag_q    = '0;

    always_comb begin
        next_tile                   = load_weights_cntr_q == MUL_SIZE-1 & weight_fifo_valid_output & weight_state != FULL;
        
        done                        = (current_weight_tile_q + 1 == max_tiles_q) & next_tile;

        compute_weights_rdy_o       = ( (weight_state == DOUBLE_BUFFER | weight_state == FULL) |
                                        (weight_state == DOUBLE_BUFFER & next_weight_tile_i)   |
                                        (weight_state == LOAD_WEIGHTS) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) 
                                        ? '1 : '0;

        compute_weights_buffered_o  = ( (weight_state == FULL) | (weight_state == DOUBLE_BUFFER) & (load_weights_cntr_q == MUL_SIZE-1) & (weight_fifo_valid_output) ) ? '1 : '0;
    end
    
    //FSM

    always_ff @(posedge clk_i, negedge rstN_i) begin
        if(rstN_i) weight_state <= RESET; //NEED ! IN FRONT OF RESET WHEN ALL RESET BEHAVIOUR HAS BEEN CHANGED
        else       weight_state <= next_weight_state;
    end

    always_comb begin
        unique case (1'b1)
            weight_state[0]: begin //RESET
                next_weight_state = (instruction_i.MAC_op[1]) ? LOAD_WEIGHTS : RESET;
            end
            weight_state[1]: begin //STALL
                next_weight_state = LOAD_WEIGHTS;
            end
            weight_state[2]: begin //LOAD_WEIGHTS
                if(done & !instruction_i.MAC_op[1]) next_weight_state = RESET;
                else next_weight_state = ( next_tile ) ? DOUBLE_BUFFER : LOAD_WEIGHTS;
            end
            weight_state[3]: begin //DOUBLE_BUFFER
                if(done & !instruction_i.MAC_op[1]) next_weight_state = RESET;
                else next_weight_state = ( next_weight_tile_i ) ? LOAD_WEIGHTS : ( (next_tile) ? FULL : DOUBLE_BUFFER );
            end
            weight_state[4]: begin //FULL
                if(done & !instruction_i.MAC_op[1]) next_weight_state = RESET;
                else next_weight_state = ( next_tile_flag_q & load_weights_cntr_q == MUL_SIZE-1 ) ? DOUBLE_BUFFER : FULL;
            end
        endcase
    end

    always_ff @( posedge clk_i ) begin
        current_weight_tile_q       <= (done) ? '0 : ( (next_tile & weight_state != RESET) ? current_weight_tile_q + 1 : current_weight_tile_q );
        read_instruction_o          <= (!iq_empty_i) & done; //need to have a read_flag register.

        unique case (1'b1)
            weight_state[0]: begin //RESET
                load_weights_cntr_q     <= '0;
                load_weights_o          <= '0;
                next_tile_flag_q        <= '0;
                read_instruction_o      <= (!iq_empty_i) ? '1 : '0;
                current_weight_tile_q   <= '0;
                max_tiles_q             <= '0;

                if (instruction_i.MAC_op[1]) begin
                    max_tiles_q         <= (instruction_i.U_dim >> 5) * (instruction_i.ITER_dim >> 5);
                    read_instruction_o  <= '0;
                end
            end

            weight_state[1]: begin //STALL BEHAVIOUR NOT IMPLEMENTED
                load_weights_cntr_q     <= '0;
                load_weights_o          <= '0;
                next_tile_flag_q        <= '0;
            end

            weight_state[2]: begin //LOAD_WEIGHTS
                next_tile_flag_q        <= '0;
                load_weights_o          <= '1;

                load_weights_cntr_q     <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

                if (next_tile) begin
                    load_weights_o              <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
                end
            end

            weight_state[3]: begin //DOUBLE_BUFFER
                next_tile_flag_q        <= '0;
                
                // When loading weights, I load the top row directly and then weights are propagated to lower rows.
                // During computation I need to double buffer on the fly. Due to the diagonal nature of the systolic array,
                // it is needed to load in weights while computation is reading weights from both COMPUTE and DOUBLE BUFFER
                // arrays. To do this, weight loading and consequently weight propagation must be enabled only on the done rows.
                // This is achieved through the load_weights_o variable which indicates which rows load/propagate weights.
                // *****Name might need to be changed to load_weights_row_selector.*****
                load_weights_o                  <= signed'(signed'(32'h80000000)>>>load_weights_cntr_q + 1);

                load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;


                if (next_tile) begin
                    load_weights_o              <= 0;
                end
            end

            weight_state[4]: begin //FULL
                load_weights_o                  <= '0;

                if(next_weight_tile_i) begin
                    next_tile_flag_q            <= 1;
                    load_weights_cntr_q         <= load_weights_cntr_q + 1;
                end

                if(next_tile_flag_q) begin
                    load_weights_cntr_q         <= load_weights_cntr_q + 1;

                    if (load_weights_cntr_q == MUL_SIZE-1) begin
                        next_tile_flag_q        <= 0;
                        load_weights_o          <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
                    end
                end
            end
        endcase
        
        if(done) begin
            if(instruction_i.MAC_op[1]) begin
                max_tiles_q             <= (instruction_i.U_dim >> 5) * (instruction_i.ITER_dim >> 5);
            end
            else begin
                load_weights_o          <= '0;
            end
        end
    end





    // always_ff @( posedge clk_i ) begin
    //     current_weight_tile_q       <= (done) ? '0 : ( (next_tile & weight_state != RESET) ? current_weight_tile_q + 1 : current_weight_tile_q );
    //     read_instruction_o          <= (!iq_empty_i) & done; //need to have a read_flag register.

    //     case(weight_state)
    //         RESET: begin
    //             load_weights_cntr_q     <= '0;
    //             load_weights_o          <= '0;
    //             next_tile_flag_q        <= '0;
    //             read_instruction_o      <= (!iq_empty_i) ? '1 : '0;
    //             current_weight_tile_q   <= '0;

    //             if (instruction_i.MAC_op[1]) begin
    //                 weight_state        <= LOAD_WEIGHTS;
    //                 max_tiles_q         <= (instruction_i.U_dim >> 5) * (instruction_i.ITER_dim >> 5);
    //                 read_instruction_o  <= '0;
    //             end
    //         end

    //         STALL: begin
    //             load_weights_o                  <= '0;
    //         end

    //         LOAD_WEIGHTS: begin
    //             load_weights_o                  <= '1;

    //             load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;


    //             if (next_tile) begin
    //                 weight_state                <= DOUBLE_BUFFER;
    //                 load_weights_o              <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
    //             end
    //         end

    //         DOUBLE_BUFFER: begin
    //             // When loading weights, I load the top row directly and then weights are propagated to lower rows.
    //             // During computation I need to double buffer on the fly. Due to the diagonal nature of the systolic array,
    //             // it is needed to load in weights while computation is reading weights from both COMPUTE and DOUBLE BUFFER
    //             // arrays. To do this, weight loading and consequently weight propagation must be enabled only on the done rows.
    //             // This is achieved through the load_weights_o variable which indicates which rows load/propagate weights.
    //             // *****Name might need to be changed to load_weights_row_selector.*****
    //             load_weights_o                  <= signed'(signed'(32'h80000000)>>>load_weights_cntr_q + 1);

    //             load_weights_cntr_q             <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;

    //             if(next_weight_tile_i) begin
    //                 weight_state                <= LOAD_WEIGHTS;
    //             end


    //             if (next_tile) begin
    //                 weight_state                <= FULL;
    //                 load_weights_o              <= 0;
    //             end
    //         end

    //         FULL: begin
    //             load_weights_o                  <= '0;

    //             if(next_weight_tile_i) begin
    //                 next_tile_flag_q            <= 1;
    //                 load_weights_cntr_q         <= load_weights_cntr_q + 1;
    //             end

    //             if(next_tile_flag_q) begin
    //                 load_weights_cntr_q         <= load_weights_cntr_q + 1;

    //                 if (load_weights_cntr_q == MUL_SIZE-1) begin
    //                     next_tile_flag_q        <= 0;
    //                     weight_state            <= DOUBLE_BUFFER;
    //                     load_weights_o          <= signed'(signed'(32'h80000000)>>>5'(load_weights_cntr_q + 1));
    //                 end
    //             end

    //         end
    //         default: begin
    //         end
    //     endcase
        
    //     if(done) begin
    //         if(instruction_i.MAC_op[1]) begin
    //             max_tiles_q             <= (instruction_i.U_dim >> 5) * (instruction_i.ITER_dim >> 5);
    //         end
    //         else begin
    //             weight_state            <= RESET;
    //             load_weights_o          <= '0;
    //         end
    //     end
    // end
endmodule
