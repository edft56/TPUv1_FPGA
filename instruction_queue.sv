`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

module instruction_queue
                        import tpu_package::*;    
                        (
                            input  clk_i,rst_i,
                            input [INSTR_SIZE-1:0] instruction_i,
                            input  write_i,
                            input  read_i,

                            output logic iq_full_o,
                            output logic [INSTR_SIZE-1:0] instruction_o
                        );

    logic [INSTR_SIZE-1:0] instruction_cache [16];

    logic [4:0] index_write_q;
    logic [4:0] next_index_write;

    initial index_write_q = '0;

    always_comb begin
        case ({write_i,read_i})
            2'b00:  next_index_write = index_write_q;
            2'b01:  next_index_write = (index_write_q != '0) ? index_write_q - 1 : index_write_q;
            2'b10:  next_index_write = index_write_q + 1;
            2'b11:  next_index_write = index_write_q;
        endcase
    end

    always_ff @( posedge clk_i ) begin
        index_write_q <= next_index_write;

        iq_full_o <= (next_index_write == 'd16) ? '1 : '0;

        if(write_i & !iq_full_o) begin
            instruction_cache[index_write_q[3:0]] <= instruction_i;
        end

        if(read_i) begin
            instruction_o <= instruction_cache[0];
        end
    end

endmodule
