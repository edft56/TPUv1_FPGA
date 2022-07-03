`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

// need to rethink this fifo but works for now

module weight_fifo
                    import tpu_package::*;    
                  ( input   clk_i, rst_i,
                    input   read_en_i,
                    input   write_en_i,
                    input   sending_data_i,
                    input   logic [W_WIDTH:0] data_i [MUL_SIZE],

                    output  logic fifo_full_o,
                    output  request_data_o,
                    output  logic       valid_o,
                    output  logic [W_WIDTH:0] data_o [MUL_SIZE]
                    );
    
    logic [W_WIDTH+1 : 0] weight_fifo_storage [32*4][32];
    logic [W_WIDTH+1 : 0] fifo_input [MUL_SIZE];
    logic [        6 : 0] fifo_cntr;

    logic fifo_full;
    logic fifo_empty;
    logic shift;
    logic write_fifo;

    initial begin
        for(int i=0; i<MUL_SIZE*4-1; i++) begin
            weight_fifo_storage[i] = '{default:0};
        end

        fifo_cntr = '0;
    end


    always_comb begin
        for(int i=0; i<MUL_SIZE; i++) begin
            fifo_input[i] = {1'b1,data_i[i]};
        end

        fifo_full       = 1'(weight_fifo_storage[0][0]>>8) & !read_en_i;
        request_data_o  = write_en_i & ~fifo_full;
        write_fifo      = (write_en_i & sending_data_i & ~fifo_full);
        shift           = !fifo_full;
    end

    always_ff @(posedge clk_i) begin
        fifo_full_o <= fifo_full;
        
        weight_fifo_storage[32*4-1] <= (write_fifo) ? fifo_input : ( (shift) ? '{default:0} : weight_fifo_storage[32*4-1] );
        
        valid_o         <= 1'(weight_fifo_storage[0][0]>>8); //check if head is valid
        if( shift ) begin
            weight_fifo_storage[0:128-2]  <= weight_fifo_storage[1:128-1]; //shift
        end

        if(read_en_i) begin
            for(int i=0; i<MUL_SIZE; i++) begin
                data_o[i]               <= 8'(weight_fifo_storage[0][i]); //read head
            end  
        end
    end

endmodule
