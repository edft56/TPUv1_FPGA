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

    logic [31:0] accumulator_storage [128][32];

    logic [31:0] accumulator_output [32];
    logic [31:0] adder_input [32];


    always_comb begin

        if(port1_rd_en_i) begin
            for(int i=0; i<32; i++) begin
                accumulator_output[i]   = accumulator_storage[addr_rd_i][i];
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

    always_ff @(posedge clk_i) begin
        if(port2_wr_en_i) begin
            for(int i=0; i<32; i++) begin
                if (accum_addr_mask_i[31-i]) begin
                    accumulator_storage[addr_wr_i][i]  <= adder_input[i] + data_i[i];
                end
            end
        end
    end

endmodule
