`timescale 1ns/1ns

//`include "packages.sv"

module accumulator( input   clk_i, rst_i,
                    input   port1_rd_en_i,
                    input   port2_wr_en_i,
                    input   add_i,
                    input   logic [31:0] data_i [32],
                    input   logic [6:0] addr_wr_i,
                    input   logic [6:0] addr_rd_i,
                    input   logic [31:0] accum_addr_mask_i,

                    output  logic [31:0] data_o [32]
                    );
    import Acc_types::*;

    logic [31:0] accumulator_storage [128][32] /* verilator public */; 

    logic [31:0] accumulator_output [32];
    logic [31:0] adder_input [32];

    always_comb begin

        if(add_i) begin
            adder_input = accumulator_output;
            data_o      = '{default:0};
        end
        else begin
            adder_input = '{default:0};
            data_o      = accumulator_output;
        end

    end

    always_ff @(posedge clk_i) begin
        if(port1_rd_en_i) begin
            for(int i=31; i>=0; i--) begin
                accumulator_output[31-i]   <= accumulator_storage[i - 31 + addr_rd_i[6:0]][31-i];
            end
        end
        else begin
            accumulator_output = '{default:0};
        end

        if(port2_wr_en_i) begin
            
            for(int i=31; i>=0; i--) begin
                if (accum_addr_mask_i[i]) begin
                    accumulator_storage[i - 31 + addr_wr_i[6:0]][31-i]  <= adder_input[31-i] + data_i[31-i];
                end
            end

        end
    end

endmodule
