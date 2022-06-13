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
                            output logic [6:0] V_dim_o,
                            output logic [6:0] U_dim_o,
                            output logic [6:0] ITER_dim_o,
                            output logic [6:0] V_dim1_o,
                            output logic [6:0] U_dim1_o,
                            output logic [6:0] ITER_dim1_o,
                            output logic [11:0] unified_buffer_addr_start_rd_o,
                            output logic [11:0] unified_buffer_addr_start_wr_o 
                        );
    logic [ 3:0] op                             = instruction_i[ 3:0];
    logic [ 6:0] V_dim                          = instruction_i[10:4];
    logic [ 6:0] U_dim                          = instruction_i[17:11];
    logic [ 6:0] ITER_dim                       = instruction_i[24:18];
    logic [11:0] unified_buffer_addr_start_rd   = instruction_i[36:25];
    logic [11:0] unified_buffer_addr_start_wr   = instruction_i[48:37];
 

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
