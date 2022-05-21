module weight_fifo( input   clk_i, rst_i,
                    input   write_i,
                    input   read_i,
                    input   logic [7:0] data_i [32],

                    output  logic       valid_o,
                    output  logic [7:0] data_o [32]
                    );
    
    logic [8:0] weight_fifo_storage [32*4][32];
    logic [8:0] fifo_input [32];

    initial begin
        for(int i=0; i<32*4-1; i++) begin
            weight_fifo_storage[i] = '{default:0};
        end
    end


    always_comb begin
        for(int i=0; i<32; i++) begin
            fifo_input[i] = {1'b1,data_i[i]};
        end
    end

    always_ff @(posedge clk_i, posedge rst_i) begin
        
        weight_fifo_storage[0:32*4-2]   <= weight_fifo_storage[1:32*4-1];

        if(write_i) begin
            weight_fifo_storage[32*4-1] <= fifo_input;
        end
        else begin
            weight_fifo_storage[32*4-1] <= '{default:0};
        end

        if(read_i) begin
            valid_o                     <= 1'(weight_fifo_storage[0][0]>>7);
            for(int i=0; i<32; i++) begin
                data_o[i]               <= 8'(weight_fifo_storage[0][i]);
            end  
        end
    end

endmodule
