`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

module accumulator
                    import tpu_package::*;    
                  ( input   clk_i, rst_i,
                    input   port1_rd_en_i,
                    input   port2_wr_en_i,
                    input   add_i,
                    input   logic [RES_WIDTH:0] data_i [MUL_SIZE],
                    input   logic [9:0] addr_wr_i,
                    input   logic [9:0] addr_rd_i,
                    input   logic [MUL_SIZE-1:0] accum_addr_mask_i,
                    input   logic [8:0] HEIGHT,
                    input   logic [8:0] WIDTH,

                    output  logic [RES_WIDTH:0] data_o [MUL_SIZE]
                    );

    logic [RES_WIDTH:0] accumulator_storage [128][MUL_SIZE] /* verilator public */;  //acc size should be 1024*32. enough to double buffer a 128x128 tile

    logic [RES_WIDTH:0] accumulator_output [MUL_SIZE];
    logic [RES_WIDTH:0] adder_input [MUL_SIZE];
    logic [8:0] upper_bound;
    logic [9:0] acc_addr_wr;

    always_comb begin
        adder_input = (add_i) ? accumulator_output : '{default:0};
        data_o      = (add_i) ? '{default:0} : accumulator_output;
        upper_bound = ( (HEIGHT>>5) * (WIDTH>>5) ) << 5;
    end

    always_ff @(posedge clk_i) begin
        if(port1_rd_en_i) begin
            for(int i=MUL_SIZE-1; i>=0; i--) begin
                accumulator_output[MUL_SIZE-1-i]   <= accumulator_storage[i - (MUL_SIZE-1) + addr_rd_i[6:0]][MUL_SIZE-1-i];
            end
        end
        else begin
            accumulator_output = '{default:0};
        end

        if(port2_wr_en_i) begin
            for(int i=MUL_SIZE-1; i>=0; i--) begin
                if (accum_addr_mask_i[i]) begin
                    //acc_addr_wr = (i - (MUL_SIZE-1) + addr_wr_i[6:0] >= upper_bound) ? i - (MUL_SIZE-1) + addr_wr_i[6:0] - upper_bound : i - (MUL_SIZE-1) + addr_wr_i[6:0];
                    accumulator_storage[i - (MUL_SIZE-1) + addr_wr_i[6:0]][MUL_SIZE-1-i]  <= adder_input[MUL_SIZE-1-i] + data_i[MUL_SIZE-1-i]; //HARDCODED 6 WILL CAUSE PROBLEMS LATER
                end
            end

        end
    end

endmodule
