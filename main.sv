`timescale 1ns/1ns
`include "packages.sv"

module main(    input clk_i, rst_i,
                input instruction_i,
                input [7:0] weight_fifo_data_in [32],

                output unified_buffer_in_test,
                output unified_buffer_out_test
            );

    wire stall_compute;
    wire load_weights_to_MAC;
    wire compute;
    wire [ 7:0] MAC_weight_input [32];
    wire [15:0] MAC_act_input [32];
    //wire [31:0] MAC_add_input [32];
    wire [31:0] MAC_output [32];

    wire unified_buffer_read;
    wire unified_buffer_write;
    wire [11:0] unified_buffer_addr_wr;
    wire [11:0] unified_buffer_addr_rd;
    wire [15:0] unified_buffer_in [32];
    wire [15:0] unified_buffer_out [32];

    wire accumulator_read_enable;
    wire accumulator_write_enable;
    wire accumulator_add;
    acc_rd_mode accumulator_read_mode;
    wire [6:0] accumulator_addr_rd;
    wire [6:0] accumulator_addr_wr;

    wire weight_fifo_write;
    wire weight_fifo_read;
    wire weight_fifo_valid_output;
    //wire [7:0] weight_fifo_data_in [32];


    MAC_systolic_array MAC_Array(   .clk_i,
                                    .rst_i,
                                    .stall_i(stall_compute), 
                                    .load_weights_i(load_weights_to_MAC), 
                                    .compute_i(compute),
                                    .mem_weight_i(MAC_weight_input),
                                    .mem_act_i(MAC_act_input),
                                    //.mem_add_i,
                                    .data_o(MAC_output)
                                    );

    Unified_Buffer_Test Uni_Buf(.clk_i,
                                .rst_i,
                                .read_i(unified_buffer_read), 
                                .write_i(unified_buffer_write),
                                .unified_buffer_in,
                                .unified_buffer_addr_wr(unified_buffer_addr_wr),
                                .unified_buffer_addr_rd(unified_buffer_addr_rd),

                                .unified_buffer_out
                                );

    systolic_data_staging sys_stage(.clk_i,
                                    .data_in(unified_buffer_out),
                                        
                                    .data_out(MAC_act_input)
                                    );

    Accumulator accum(  .clk_i,
                        .rst_i,
                        .port1_rd_en_i(accumulator_read_enable),
                        .port2_wr_en_i(accumulator_write_enable),
                        .add_i(accumulator_add),
                        .accumulator_read_mode,
                        .data_i(MAC_output),
                        .addr_wr(accumulator_addr_rd),
                        .addr_rd(accumulator_addr_wr),

                        .data_o(unified_buffer_in)
                        );

    weight_fifo w_fifo( .clk_i,
                        .rst_i,
                        .read_i(weight_fifo_read),
                        .write_i(weight_fifo_write),
                        .data_i(weight_fifo_data_in),

                        .valid_o(weight_fifo_valid_output),
                        .data_o(MAC_weight_input)
                        );

    control_unit ctrl_unit( .clk_i,
                            .rst_i,
                            .instruction_i,
                            //.next_weight_tile_rdy_i,
                            .activations_rdy_i,
                            .weight_fifo_valid_output,

                            .load_weights_o(load_weights_to_MAC),
                            .load_activations_o(unified_buffer_read),
                            .stall_compute_o(stall_compute),
                            .accumulator_read_mode
                            );

endmodule
