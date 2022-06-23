`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module instruction_unit
                        import tpu_package::*;    
                        (
                            input  clk_i,rst_i,
                            input [INSTR_SIZE-1:0] instruction_i,
                            input  write_i,
                            input  instruction_read_i,

                            output logic iq_full_o,
                            decode_registers_t decoded_instruction_o
                        );

    logic [INSTR_SIZE-1:0] instruction_input_register_q;
    decode_registers_t decoded_instruction_cache [16];

    logic [4:0] index_write_q;
    logic [4:0] next_index_write;

    initial index_write_q = '0;

    always_comb begin
        case ({write_i,instruction_read_i})
            2'b00:  next_index_write = index_write_q;
            2'b01:  next_index_write = (index_write_q != '0) ? index_write_q - 1 : index_write_q;
            2'b10:  next_index_write = index_write_q + 1;
            2'b11:  next_index_write = index_write_q;
        endcase
    end

    always_ff @( posedge clk_i ) begin
        index_write_q <= next_index_write;

        iq_full_o <= (next_index_write == 'd16) ? '1 : '0;

        
        decoded_instruction_o <= decoded_instruction_cache[0];
        

        if(write_i & !iq_full_o) begin
            instruction_input_register_q <= instruction_i;
        end
        
        case(instruction_input_register_q[ 3: 0])
                4'b0001: begin
                    decoded_instruction_cache[index_write_q[3:0]].MAC_op                        <= 3'b010;
                    decoded_instruction_cache[index_write_q[3:0]].V_dim                         <= instruction_input_register_q[11: 4];
                    decoded_instruction_cache[index_write_q[3:0]].U_dim                         <= instruction_input_register_q[19:12];
                    decoded_instruction_cache[index_write_q[3:0]].ITER_dim                      <= instruction_input_register_q[27:20];
                    decoded_instruction_cache[index_write_q[3:0]].unified_buffer_addr_start_rd  <= instruction_input_register_q[39:28];
                    decoded_instruction_cache[index_write_q[3:0]].unified_buffer_addr_start_wr  <= instruction_input_register_q[51:40];

                    decoded_instruction_cache[index_write_q[3:0]].V_dim1                        <= instruction_input_register_q[11: 4] - 1;
                    decoded_instruction_cache[index_write_q[3:0]].U_dim1                        <= instruction_input_register_q[19:12] - 1;
                    decoded_instruction_cache[index_write_q[3:0]].ITER_dim1                     <= instruction_input_register_q[27:20] - 1;
                end
            
                default: begin
                end
            endcase
    end

endmodule

