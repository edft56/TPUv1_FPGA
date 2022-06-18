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
                    input   logic [7:0] V_dim_i,
                    input   logic [7:0] U_dim_i,
                    input   logic [RES_WIDTH:0] data_i [MUL_SIZE],
                    input   logic [9:0] addr_wr_i,
                    input   logic [9:0] addr_rd_i,
                    input   logic [MUL_SIZE-1:0] accum_addr_mask_i,
                    input   logic [MUL_SIZE-1:0] accum_addr_mask_rd_i,
                    //input   logic [8:0] HEIGHT,
                    //input   logic [8:0] WIDTH,

                    output  logic [RES_WIDTH:0] data_o [MUL_SIZE]
                    );

    logic [RES_WIDTH:0] accumulator_storage [512][MUL_SIZE] /* verilator public */;  //acc size should be 1024*32. enough to double buffer a 128x128 tile

    logic [RES_WIDTH:0] accumulator_output [MUL_SIZE];
    logic [RES_WIDTH:0] adder_input [MUL_SIZE];

    logic [9:0] addr_wr;
    logic [9:0] addr_rd;
    logic [9:0] max_acc_addr;

    logic [9:0] bank_addr_array_wr_q [31]; 
    logic [9:0] bank_addr_array_rd_q [31];
    logic [9:0] bank_addr_array_wr [32];
    logic [9:0] bank_addr_array_rd [32];
    //logic [8:0] upper_bound;
    //logic [9:0] acc_addr_wr;

    initial bank_addr_array_wr_q = '{default:0};
    initial bank_addr_array_rd_q = '{default:0};

    always_comb begin
        max_acc_addr = V_dim_i * ( ((U_dim_i>>5) - 1 > 0) ? (U_dim_i>>5) - 1 : 1 ); 
        adder_input  = (add_i) ? accumulator_output : '{default:0};
        data_o       = (add_i) ? '{default:0} : accumulator_output;

        addr_rd      = addr_rd_i & max_acc_addr; //maybe think of another way
        addr_wr      = addr_wr_i & max_acc_addr; //maybe think of another way
        //upper_bound = ( (HEIGHT>>5) * (WIDTH>>5) ) << 5;

        bank_addr_array_wr[0] = addr_wr_i;
        bank_addr_array_wr[1:31] = bank_addr_array_wr_q;
        bank_addr_array_rd[0] = addr_rd_i;
        bank_addr_array_rd[1:31] = bank_addr_array_rd_q;
    end

    always_ff @(posedge clk_i) begin
        if(port1_rd_en_i) begin
            for(int i=MUL_SIZE-1; i>=0; i--) begin
                if (accum_addr_mask_rd_i[i]) begin
                    accumulator_output[MUL_SIZE-1-i]   <= accumulator_storage[bank_addr_array_rd[MUL_SIZE-1-i]][MUL_SIZE-1-i]; //need a read mask
                end
            end
        end
        else begin
            accumulator_output <= '{default:0};
        end

        if(port2_wr_en_i) begin
            for(int i=MUL_SIZE-1; i>=0; i--) begin
                if (accum_addr_mask_i[i]) begin
                    accumulator_storage[bank_addr_array_wr[MUL_SIZE-1-i]][MUL_SIZE-1-i]  <= adder_input[MUL_SIZE-1-i] + data_i[MUL_SIZE-1-i]; 
                end
            end

        end
    end

    always_ff @(posedge clk_i) begin //update bank addr regs
        if(port2_wr_en_i) begin
            bank_addr_array_wr_q[0] <= addr_wr_i;
            for(int i=0; i<30; i++) begin
                bank_addr_array_wr_q[i+1] <= bank_addr_array_wr_q[i];
            end

            bank_addr_array_rd_q[0] <= addr_rd_i;
            for(int i=0; i<30; i++) begin
                bank_addr_array_rd_q[i+1] <= bank_addr_array_rd_q[i];
            end
        end
    end

endmodule
