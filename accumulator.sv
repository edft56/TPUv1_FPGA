module Accumulator( input   clk_i, rst_i,
                    input   cs_i, wr_i,
                    input   logic [15:0] data_i,
                    input   logic [9:0] addr_wr,
                    input   logic [9:0] addr_rd,

                    output  logic [15:0] data_o
                    );

    logic [15:0] mem_storage_q [1024];

    always_ff @(posedge clk_i, posedge rst_i) begin
        if(cs_i & wr_i) begin
            mem_storage_q[addr_wr]  <= data_i;
            data_o                  <= mem_storage_q[addr_rd];
        end
        else if (cs_i & ~wr_i) begin
            data_o                  <= mem_storage_q[addr_rd];
        end
        else begin
            data_o                  <= data_o;
        end

    end

endmodule