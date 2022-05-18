module Bram(input   clk_i, rst_i,
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

module Uram(input   clk_i, rst_i,
            input   cs_i, wr_i,
            input   logic [63:0] data_i,
            input   logic [11:0] addr_wr,
            input   logic [11:0] addr_rd,

            output  logic [63:0] data_o
            );

    logic [63:0] mem_storage_q [4096];

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


module Unified_Buffer(  input clk_i,rst_i,
                        input read_i, write_i,
                        input logic [14:0] unified_buffer_addr_wr,
                        input logic [14:0] unified_buffer_addr_rd
                        );
    
    logic [ 2:0] select_URAM_addr_wr    = unified_buffer_addr_wr [14:12];
    logic [11:0] internal_URAM_addr_wr  = unified_buffer_addr_wr [11: 0];
    logic [ 2:0] select_URAM_addr_rd    = unified_buffer_addr_rd [14: 12];
    logic [11:0] internal_URAM_addr_rd  = unified_buffer_addr_rd [11: 0];

    logic [63:0] unified_buffer_out [8];
    logic [63:0] unified_buffer_in [8];
    logic [ 7:0] chip_select_URAM_wr; 
    logic [ 7:0] chip_select_URAM_rd; 

    decoder_3_to_8 dec0 (write_i, select_URAM_addr_wr, chip_select_URAM_wr);
    decoder_3_to_8 dec1 (read_i, select_URAM_addr_rd, chip_select_URAM_rd);

    genvar i,j;
    generate
        for(i=0; i<8; i++) begin
            for(j=0; j<8; j++) begin
                Uram Uram_array(.clk_i, 
                                .rst_i,
                                .cs_i(chip_select_URAM_wr[j] | chip_select_URAM_rd[j]),
                                .wr_i(write_i),
                                .data_i(unified_buffer_in[j]),
                                .addr_wr(internal_URAM_addr_wr),
                                .addr_rd(internal_URAM_addr_rd),

                                .data_o(unified_buffer_out[j])
                                );
            end

        end
    
    endgenerate

endmodule


module decoder_3_to_8(  input en,
                        input logic [2:0] in,
                        output logic [7:0] out
                        );
    always_comb begin
        case ({en,in})
            4'b1000:  out[0] = 1'b1;
            4'b1001:  out[1] = 1'b1;
            4'b1010:  out[2] = 1'b1;
            4'b1011:  out[3] = 1'b1;
            4'b1100:  out[4] = 1'b1;
            4'b1101:  out[5] = 1'b1;
            4'b1110:  out[6] = 1'b1;
            4'b1111:  out[7] = 1'b1;
            default:  out    = 8'd0;
        endcase
    end

endmodule
