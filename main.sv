`timescale 1ns/1ns
`include "packages.sv"

module main(    input clk_i, rst_i,
                input instruction_i,
                input [7:0] weight_fifo_data_in [32],
                input [8:0] H_DIM_i,
                input [8:0] W_DIM_i,
                input sending_fifo_data_i,

                output unified_buffer_in_test,
                output unified_buffer_out_test,
                output request_fifo_data_o,
                output done_o
            );

    import Acc_types::*;

    wire stall_compute;
    wire load_weights_to_MAC;
    wire MAC_compute;
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
    
    wire [6:0] accumulator_addr_rd;
    wire [6:0] accumulator_addr_wr;
    wire [31:0] accum_addr_mask;
    wire weight_fifo_write;
    //wire weight_fifo_read;
    wire weight_fifo_valid_output;
    //wire [7:0] weight_fifo_data_in [32];

    wire act_data_rdy;


    MAC_systolic_array MAC_Array(   .clk_i,
                                    .rst_i,
                                    .stall_i(1'b0), 
                                    .load_weights_i(load_weights_to_MAC), 
                                    .compute_i(MAC_compute),
                                    .mem_weight_i(MAC_weight_input),
                                    .mem_act_i(MAC_act_input),
                                    //.mem_add_i,
                                    .data_o(MAC_output)
                                    );

    unified_buffer Uni_Buf(.clk_i,
                                .rst_i,
                                .read_i(unified_buffer_read), 
                                .write_i(unified_buffer_write),
                                .unified_buffer_in,
                                .unified_buffer_addr_wr(unified_buffer_addr_wr),
                                .unified_buffer_addr_rd(unified_buffer_addr_rd),

                                .unified_buffer_out
                                );

    systolic_data_staging sys_stage(.clk_i,
                                    .data_i(unified_buffer_out),
                                    .read_i(unified_buffer_read),
                                        
                                    .act_data_rdy_o(act_data_rdy),
                                    .data_o(MAC_act_input)
                                    );

    accumulator accum(  .clk_i,
                        .rst_i,
                        .port1_rd_en_i(1'b1),
                        .port2_wr_en_i(accumulator_write_enable),
                        .add_i(accumulator_add),
                        .data_i(MAC_output),
                        .addr_wr_i(accumulator_addr_wr),
                        .addr_rd_i(accumulator_addr_rd),
                        .accum_addr_mask_i(accum_addr_mask),

                        .data_o()//.data_o(unified_buffer_in)
                        );

    weight_fifo w_fifo( .clk_i,
                        .rst_i,
                        .read_en_i(load_weights_to_MAC),
                        .write_en_i(1'b1),
                        .data_i(weight_fifo_data_in),
                        .sending_data_i(sending_fifo_data_i),

                        .request_data_o(request_fifo_data_o),
                        .valid_o(weight_fifo_valid_output),
                        .data_o(MAC_weight_input)
                        );

    control_unit ctrl_unit( .clk_i,
                            .rst_i,
                            .instruction_i,
                            //.next_weight_tile_rdy_i,
                            .activations_rdy_i(act_data_rdy),
                            .weight_fifo_valid_output,
                            .accumulator_start_addr_wr_i('0),
                            .H_DIM_i,
                            .W_DIM_i,

                            .load_weights_o(load_weights_to_MAC),
                            .load_activations_o(unified_buffer_read),
                            .stall_compute_o(stall_compute),
                            .MAC_compute_o(MAC_compute),
                            .read_accumulator_o(accumulator_read_enable),
                            .write_accumulator_o(accumulator_write_enable),
                            .accumulator_addr_wr_o(accumulator_addr_wr),
                            .accumulator_addr_rd_o(accumulator_addr_rd),
                            .accum_addr_mask_o(accum_addr_mask),
                            .accumulator_add_o(accumulator_add),
                            .done_o
                            );

endmodule
