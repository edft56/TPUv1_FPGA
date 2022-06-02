`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module memory_general
                        import tpu_package::*;    
                        (  input   clk_i, rst_i,
                        input   port1_wr_i,
                        input   port2_rd_i,
                        input   logic [ACT_WIDTH:0] data_i [MUL_SIZE],
                        input   logic [11:0] addr_wr_i,
                        input   logic [11:0] addr_rd_i,

                        output  logic [ACT_WIDTH:0] data_o [MUL_SIZE]
                        );

    logic [ACT_WIDTH:0] mem_storage_q [4096][MUL_SIZE];

    logic [4:0] times_read;

    initial begin
        // for(int i=0; i<4096; i++) begin
        //     //mem_storage_q[i] = '{default:(ACT_WIDTH+1)'(1)};//'{default:16'(i%5)};
        //     for(int j=0; j<32; j++) begin
        //         mem_storage_q[i][j] = j%4;
        //     end
        // end

        fd = $fopen( "mem.data", "r");
        for (int i=0; i<4; i++) begin
            for (int j=0; j<3; j++) begin
                status = $fscanf(fd, "%b", mem_storage_q[i][j]);
            end
        end
    end

    always_ff @(posedge clk_i) begin
        if(port1_wr_i) begin
            mem_storage_q[addr_wr_i]  <= data_i;
        end

        if (port2_rd_i) begin
            data_o                  <= mem_storage_q[addr_rd_i];
            //data_o                  <= mem_storage_q[times_read];
            //times_read <= times_read + 1;
        end
        else begin
            data_o                  <= data_o;
        end

    end

endmodule


module unified_buffer
                        import tpu_package::*;    
                        (  input clk_i,rst_i,
                            input read_i, write_i,
                            input logic [ACT_WIDTH:0] unified_buffer_in [MUL_SIZE],
                            input logic [11:0] unified_buffer_addr_wr,
                            input logic [11:0] unified_buffer_addr_rd,

                            output logic [ACT_WIDTH:0] unified_buffer_out [MUL_SIZE]
                            );

    
    memory_general mem_array(   .clk_i, 
                                .rst_i,
                                .port1_wr_i(write_i),
                                .port2_rd_i(read_i),
                                .data_i(unified_buffer_in),
                                .addr_wr_i(unified_buffer_addr_wr),
                                .addr_rd_i(unified_buffer_addr_rd),

                                .data_o(unified_buffer_out)
                                );

endmodule

