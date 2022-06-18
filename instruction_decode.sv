`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

module instruction_decode
                        import tpu_package::*;    
                        (
                            input  clk_i,rst_i,
                            input [INSTR_SIZE-1:0] instruction_i,

                            output logic [2:0] MAC_op_o,
                            output logic [7:0] V_dim_o,
                            output logic [7:0] U_dim_o,
                            output logic [7:0] ITER_dim_o,
                            output logic [6:0] V_dim1_o,
                            output logic [6:0] U_dim1_o,
                            output logic [6:0] ITER_dim1_o,
                            output logic [11:0] unified_buffer_addr_start_rd_o,
                            output logic [11:0] unified_buffer_addr_start_wr_o 
                        );
    logic [ 3:0] op                             = instruction_i[ 3:0];
    logic [ 7:0] V_dim                          = instruction_i[11:4];
    logic [ 7:0] U_dim                          = instruction_i[19:12];
    logic [ 7:0] ITER_dim                       = instruction_i[27:20];
    logic [11:0] unified_buffer_addr_start_rd   = instruction_i[39:28];
    logic [11:0] unified_buffer_addr_start_wr   = instruction_i[51:40];
    
    initial MAC_op_o = '0;

    always_ff @( posedge clk_i ) begin
        case(op)
            4'b0001: begin
                MAC_op_o                        <= 3'b010;

                V_dim_o                         <= V_dim;
                U_dim_o                         <= U_dim;
                ITER_dim_o                      <= ITER_dim;

                V_dim1_o                         <= V_dim - 1;
                U_dim1_o                         <= U_dim - 1;
                ITER_dim1_o                      <= ITER_dim - 1;
                
                unified_buffer_addr_start_rd_o  <= unified_buffer_addr_start_rd;
                unified_buffer_addr_start_wr_o  <= unified_buffer_addr_start_wr;
            end
            default: begin

            end
        endcase
    end

endmodule
