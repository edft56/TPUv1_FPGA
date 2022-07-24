`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module unified_buffer_control_unit
                    import tpu_package::*;    
                  (input clk_i,rstN_i,
                    input compute_weights_rdy_i,
                    input decoded_instr_t instruction_i,
                    input instruction_valid_i,

                    output logic invalidate_instruction_o,
                    output logic unified_buffer_read_en_o,
                    output logic [11:0] unified_buffer_addr_rd_o
                    );

    typedef enum logic [2:0] {
                                RESET = 3'b001, 
                                STALL = 3'b010, 
                                READ  = 3'b100
                                } u_buf_states_t;

    u_buf_states_t unified_buffer_state, next_unified_buffer_state;

    logic [2:0] tile_x;
    logic [2:0] tile_y;
    logic next_tile;
    logic done_tiles_y;
    logic done_tiles_x;

    logic [11:0] next_tile_cntr_q;
    logic [ 2:0] tile_x_q;
    logic [ 2:0] tile_y_q;
    logic [ 6:0] U_dim1_q;
    logic [ 7:0] V_dim_q;
    logic [ 6:0] ITER_dim1_q;
    logic [11:0] unified_buffer_start_addr_rd_q;

    initial unified_buffer_addr_rd_o    = '0;
    initial tile_x_q                    = '0;
    initial tile_y_q                    = '0;
    initial next_tile_cntr_q            = '0;
    initial unified_buffer_state        = RESET;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    // I want to use weight tiles just once. This means that input tiles are going to be used multiple times.
    // To achieve this, tiled outer products are calculated. The output tile residing in the accumulator is filled entirely with partial products.
    // Then, these products are added upon until the final output tile is computed.
    // What does this mean for the reading pattern of the unified buffer?
    // First all (y,0) input tiles are read weight_tiles_x times. The remaining input tiles in the x dimension are read accordingly. 
    //
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always_comb begin 
        next_tile = (next_tile_cntr_q + 1) == V_dim_q;

        done_tiles_y = (tile_y_q == 4'(U_dim1_q>>5)) & next_tile;
        done_tiles_x = (tile_x_q == 4'(ITER_dim1_q>>5)) & done_tiles_y;

        tile_y = (done_tiles_y) ? '0 : ( next_tile    ? tile_y_q + 1 : tile_y_q );
        tile_x = (done_tiles_x) ? '0 : ( done_tiles_y ? tile_x_q + 1 : tile_x_q );

    end
    
    //FSM

    always_ff @(posedge clk_i, negedge rstN_i) begin
        if(rstN_i) unified_buffer_state <= RESET; //NEED ! IN FRONT OF RESET WHEN ALL RESET BEHAVIOUR HAS BEEN CHANGED
        else        unified_buffer_state <= next_unified_buffer_state;
    end

    always_comb begin
        unique case (1'b1)
            unified_buffer_state[0]: begin //RESET
                next_unified_buffer_state = (instruction_valid_i & instruction_i.MAC_op[1]) ? STALL : RESET;
            end
            unified_buffer_state[1]: begin //STALL
                next_unified_buffer_state = (compute_weights_rdy_i) ? READ : STALL;
            end
            unified_buffer_state[2]: begin //READ
                next_unified_buffer_state = ( done_tiles_x & !(instruction_valid_i & instruction_i.MAC_op[1]) ) ? RESET : READ;
            end
        endcase
    end

    always_ff @( posedge clk_i ) begin
        invalidate_instruction_o    <= (invalidate_instruction_o) ? '0 : invalidate_instruction_o;
        tile_y_q <= tile_y;
        tile_x_q <= tile_x;

        unique case (1'b1)
            unified_buffer_state[0]: begin //RESET
                unified_buffer_start_addr_rd_q  <= '0;
                unified_buffer_read_en_o        <= '0;
                unified_buffer_addr_rd_o        <= '0;
                tile_x_q                        <= '0;
                tile_y_q                        <= '0;
                next_tile_cntr_q                <= '0;
                U_dim1_q                        <= '0;
                V_dim_q                         <= '0;
                ITER_dim1_q                     <= '0;
                invalidate_instruction_o        <= (instruction_valid_i) ? '1 : 0;

                if(next_unified_buffer_state == STALL) begin
                    unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
                    U_dim1_q                        <= instruction_i.U_dim1;
                    V_dim_q                         <= instruction_i.V_dim;
                    ITER_dim1_q                     <= instruction_i.ITER_dim1;
                end
            end
            unified_buffer_state[1]: begin //STALL
                if(next_unified_buffer_state == READ) begin
                    unified_buffer_read_en_o <= '1;
                end
            end
            unified_buffer_state[2]: begin //READ
                unified_buffer_read_en_o <= '1;

                next_tile_cntr_q <= (next_tile) ? '0 : next_tile_cntr_q + 1;

                if(done_tiles_x) begin
                    if(instruction_valid_i & instruction_i.MAC_op[1]) begin
                        unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
                        U_dim1_q                        <= instruction_i.U_dim1;
                        V_dim_q                         <= instruction_i.V_dim;
                        ITER_dim1_q                     <= instruction_i.ITER_dim1;
                        unified_buffer_addr_rd_o        <= instruction_i.unified_buffer_start_addr_rd;

                        invalidate_instruction_o        <= '1;
                    end
                end
                else if (next_tile) unified_buffer_addr_rd_o <= unified_buffer_start_addr_rd_q + (tile_x)*V_dim_q;
                else unified_buffer_addr_rd_o               <= unified_buffer_addr_rd_o + 1;
            end
        endcase
    end
    
    //FSM end

    //assume tiles are written to unified buffer in the required order
    // always_ff @( posedge clk_i ) begin
    //     invalidate_instruction_o    <= (invalidate_instruction_o) ? '0 : invalidate_instruction_o;
    //     tile_y_q <= tile_y;
    //     tile_x_q <= tile_x;

    //     case(unified_buffer_state)
    //         RESET: begin
    //             unified_buffer_read_en_o    <= '0;
    //             unified_buffer_addr_rd_o    <= '0;
    //             tile_x_q                    <= '0;
    //             tile_y_q                    <= '0;
    //             next_tile_cntr_q            <= '0;

    //             if (instruction_valid_i & instruction_i.MAC_op[1]) begin
    //                 unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
    //                 unified_buffer_state            <= STALL;
    //                 U_dim1_q                        <= instruction_i.U_dim1;
    //                 V_dim_q                         <= instruction_i.V_dim;
    //                 ITER_dim1_q                     <= instruction_i.ITER_dim1;

    //             end
    //             if (instruction_valid_i) invalidate_instruction_o        <= '1;
    //         end
    //         STALL: begin
    //             if (compute_weights_rdy_i) begin
    //                 unified_buffer_state <= READ;
    //                 unified_buffer_read_en_o <= '1;
    //             end
    //         end
    //         READ: begin
    //             unified_buffer_read_en_o <= '1;

    //             next_tile_cntr_q <= (next_tile) ? '0 : next_tile_cntr_q + 1;

    //             if(done_tiles_x) begin
    //                 if(instruction_valid_i & instruction_i.MAC_op[1]) begin
    //                     unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
    //                     U_dim1_q                        <= instruction_i.U_dim1;
    //                     V_dim_q                         <= instruction_i.V_dim;
    //                     ITER_dim1_q                     <= instruction_i.ITER_dim1;
    //                     unified_buffer_addr_rd_o        <= instruction_i.unified_buffer_start_addr_rd;

    //                     invalidate_instruction_o        <= '1;
    //                 end
    //                 else begin
    //                     unified_buffer_state            <= RESET;
    //                 end
    //             end
    //             else if(next_tile) unified_buffer_addr_rd_o <= unified_buffer_start_addr_rd_q + (tile_x)*V_dim_q;
    //             else unified_buffer_addr_rd_o               <= unified_buffer_addr_rd_o + 1;
    //         end
    //         default: begin
    //         end
    //     endcase

    // end

endmodule
