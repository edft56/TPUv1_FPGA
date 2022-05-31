`timescale 1ns/1ns

module weight_fifo( input   clk_i, rst_i,
                    input   read_en_i,
                    input   write_en_i,
                    input   sending_data_i,
                    input   logic [7:0] data_i [32],

                    output  logic fifo_full_o,
                    output  request_data_o,
                    output  logic       valid_o,
                    output  logic [7:0] data_o [32]
                    );
    
    logic [8:0] weight_fifo_storage [32*4][32];
    logic [8:0] fifo_input [32];
    logic [6:0] fifo_cntr;

    logic fifo_full;
    logic fifo_empty;
    logic shift;
    logic write_fifo;

    initial begin
        for(int i=0; i<32*4-1; i++) begin
            weight_fifo_storage[i] = '{default:0};
        end

        fifo_cntr = '0;
    end


    always_comb begin
        for(int i=0; i<32; i++) begin
            fifo_input[i] = {1'b1,data_i[i]};
        end

        // fifo_empty      = (fifo_cntr == '0);
        // fifo_full       = (fifo_cntr == 'd127);
        fifo_full       = 1'(weight_fifo_storage[0][0]>>8) & !read_en_i;
        request_data_o  = write_en_i & ~fifo_full;
        write_fifo      = (write_en_i & sending_data_i & ~fifo_full);
        shift           = !fifo_full;

        //valid_o         = 1'(weight_fifo_storage[0][0]>>8); //check if head is valid
    end

    always_ff @(posedge clk_i) begin
        // case({valid_o, write_fifo})
        //     2'b00: fifo_cntr <= fifo_cntr;
        //     2'b01: fifo_cntr <= (~fifo_full) ? fifo_cntr + 1 : fifo_cntr;
        //     2'b10: fifo_cntr <= (~fifo_empty) ? fifo_cntr - 1 : fifo_cntr;
        //     2'b11: fifo_cntr <= fifo_cntr;
        // endcase
        
        fifo_full_o <= fifo_full;
        
        weight_fifo_storage[32*4-1] <= (write_fifo) ? fifo_input : ( (shift) ? '{default:0} : weight_fifo_storage[32*4-1] );
        

        if( shift ) begin
            weight_fifo_storage[0:128-2]  <= weight_fifo_storage[1:128-1]; //shift
        end

        valid_o         <= 1'(weight_fifo_storage[0][0]>>8); //check if head is valid

        if(read_en_i) begin
            //valid_o         <= 1'(weight_fifo_storage[0][0]>>8); //check if head is valid
            for(int i=0; i<32; i++) begin
                data_o[i]               <= 8'(weight_fifo_storage[0][i]); //read head
            end  
        end
        // else begin
        //     valid_o         <= '0;
        // end
    end

endmodule
