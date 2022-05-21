`include "packages.sv"

module Accumulator( input   clk_i, rst_i,
                    input   port1_rd_en_i,
                    input   port2_wr_en_i,
                    input   add_i,
                    input   Acc_types::acc_rd_mode accumulator_read_mode,
                    input   logic [31:0] data_i [32],
                    input   logic [6:0] addr_wr,
                    input   logic [6:0] addr_rd,

                    output  logic [31:0] data_o [32]
                    );
    import Acc_types::*;

    logic [31:0] accumulator_storage [128][32];
    diag_addr_array_t diag_addr;

    logic [31:0] accumulator_output [32];
    logic [31:0] adder_input [32];

    assign diag_addr = diag_addr_LUT(addr_rd);

    always_comb begin

        if(port1_rd_en_i) begin
            if(accumulator_read_mode == NORMAL) begin
                for(int i=0; i<32; i++) begin
                    accumulator_output[i]   = accumulator_storage[addr_rd][i];
                end
            end
            else begin
                for(int i=0; i<32; i++) begin
                    accumulator_output[i]   = accumulator_storage[diag_addr[i]][i];
                end
            end
        end
        else begin
            accumulator_output = '{default:0};
        end

        if(add_i) begin
            adder_input = accumulator_output;
            data_o      = '{default:0};
        end
        else begin
            adder_input = '{default:0};
            data_o      = accumulator_output;
        end

    end

    always_ff @(posedge clk_i, posedge rst_i) begin
        if(port2_wr_en_i) begin
            for(int i=0; i<32; i++) begin
                accumulator_storage[addr_wr][i]  <= adder_input[i] + data_i[i];
            end
        end
    end

endmodule
