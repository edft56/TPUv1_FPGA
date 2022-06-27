`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module unified_buffer_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input compute_weights_rdy_i,
                    input decoded_instr_t instruction_i,

                    output logic unified_buffer_read_en_o,
                    output logic [11:0] unified_buffer_addr_rd_o
                    );

    enum logic [1:0] {RESET, STALL, READ} unified_buffer_state;


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
    

    //assume tiles are written to unified buffer in the required order
    always_ff @( posedge clk_i ) begin
        tile_y_q <= tile_y;
        tile_x_q <= tile_x;

        case(unified_buffer_state)
            RESET: begin
                unified_buffer_read_en_o    <= '0;
                unified_buffer_addr_rd_o    <= '0;
                tile_x_q                    <= '0;
                tile_y_q                    <= '0;
                next_tile_cntr_q            <= '0;

                if (instruction_i.MAC_op[1]) begin
                    unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
                    unified_buffer_state            <= STALL;
                    U_dim1_q                        <= instruction_i.U_dim1;
                    V_dim_q                         <= instruction_i.V_dim;
                    ITER_dim1_q                     <= instruction_i.ITER_dim1;
                end
            end
            STALL: begin
                if (compute_weights_rdy_i) begin
                    unified_buffer_state <= READ;
                    unified_buffer_read_en_o <= '1;
                end
            end
            READ: begin
                unified_buffer_read_en_o <= '1;

                next_tile_cntr_q <= (next_tile) ? '0 : next_tile_cntr_q + 1;

                if(done_tiles_x) begin
                    if(instruction_i.MAC_op[1]) begin
                        unified_buffer_start_addr_rd_q  <= instruction_i.unified_buffer_start_addr_rd;
                        unified_buffer_state            <= READ;
                        U_dim1_q                        <= instruction_i.U_dim1;
                        V_dim_q                         <= instruction_i.V_dim;
                        ITER_dim1_q                     <= instruction_i.ITER_dim1;
                        unified_buffer_addr_rd_o        <= instruction_i.unified_buffer_start_addr_rd + (tile_x)*V_dim_q; //i dont like this. maybe buffer start address???
                    end
                    else begin
                        unified_buffer_state            <= RESET;
                        //unified_buffer_read_en_o        <= '0;
                    end
                end
                if(next_tile) unified_buffer_addr_rd_o <= unified_buffer_start_addr_rd_q + (tile_x)*V_dim_q;
                else unified_buffer_addr_rd_o               <= unified_buffer_addr_rd_o + 1;
            end
            default: begin
            end
        endcase

    end

endmodule
