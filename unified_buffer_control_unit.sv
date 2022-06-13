`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module unified_buffer_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input instruction_i,
                    input compute_weights_rdy_i,
                    input [8:0] H_DIM_i,
                    input [8:0] W_DIM_i,
                    input [11:0] unified_buffer_start_addr_rd_i,

                    output logic unified_buffer_read_en_o,
                    output logic [11:0] unified_buffer_addr_rd_o
                    );

    enum logic {STALL, READ} unified_buffer_state;

    logic [1:0] tile_x;
    logic [1:0] tile_y;
    logic next_tile;
    logic done_tiles_y;
    logic done_tiles_x;

    logic [1:0] tile_x_q;
    logic [1:0] tile_y_q;

    initial unified_buffer_addr_rd_o = unified_buffer_start_addr_rd_i;
    initial tile_x_q = '0;
    initial tile_y_q = '0;

    always_comb begin
        next_tile = unified_buffer_addr_rd_o[5:0] == H_DIM_i; //hardcoded 5 will cause problems later

        done_tiles_y = (tile_y_q == 4'(H_DIM_i>>5)) & next_tile;
        done_tiles_x = (tile_x_q == 4'(W_DIM_i>>5)) & done_tiles_y;

        tile_y = (done_tiles_y) ? '0 : ( next_tile    ? tile_y_q + 1 : tile_y_q );
        tile_x = (done_tiles_x) ? '0 : ( done_tiles_y ? tile_x_q + 1 : tile_x_q );
    end
    

    //assume tiles are written to unified buffer in the required order
    always_ff @( posedge clk_i ) begin
        tile_y_q <= tile_y;
        tile_x_q <= tile_x;

        case(unified_buffer_state)
            STALL: begin
                if (instruction_i & compute_weights_rdy_i) begin
                    unified_buffer_state <= READ;
                    unified_buffer_read_en_o <= '1;
                end
            end
            READ: begin
                unified_buffer_read_en_o <= '1;

                if(next_tile) unified_buffer_addr_rd_o <= unified_buffer_start_addr_rd_i + (tile_x)*(((H_DIM_i>>5)+1)<<5);
                else unified_buffer_addr_rd_o <= unified_buffer_addr_rd_o + 1;
            end
        endcase

    end

endmodule
