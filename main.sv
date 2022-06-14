`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

module main
            import tpu_package::*;
            (   input clk_i, rst_i,
                input [INSTR_SIZE-1:0] instruction_i,
                input write_instruction_i,
                input [W_WIDTH:0] weight_fifo_data_in [MUL_SIZE],
                input sending_fifo_data_i,

                output instruction_queue_full_o,
                output request_fifo_data_o,
                output done_o
            );

    wire stall_compute;
    wire [MUL_SIZE-1:0] load_weights_to_MAC;
    wire MAC_compute;
    wire [W_WIDTH:0] MAC_weight_input [MUL_SIZE];
    wire [ACT_WIDTH:0] MAC_act_input [MUL_SIZE];
    wire [RES_WIDTH:0] MAC_output [MUL_SIZE];
    wire [MUL_SIZE-1 : 0] compute_weight_sel [MUL_SIZE];
    wire load_activations_to_MAC;
    wire [2:0] MAC_op;

    wire unified_buffer_read;
    wire unified_buffer_write;
    wire [11:0] unified_buffer_addr_wr;
    wire [11:0] unified_buffer_addr_rd;
    wire [ACT_WIDTH:0] unified_buffer_in [MUL_SIZE];
    wire [ACT_WIDTH:0] unified_buffer_out [MUL_SIZE];

    wire accumulator_read_enable;
    wire accumulator_write_enable;
    wire accumulator_add;
    
    wire [9:0] accumulator_addr_rd;
    wire [9:0] accumulator_addr_wr;
    wire [31:0] accum_addr_mask;
    wire weight_fifo_write;

    wire weight_fifo_full;
    wire weight_fifo_valid_output;

    wire act_data_rdy;

    wire next_weight_tile;
    wire compute_weights_buffered;
    wire compute_weights_rdy;

    wire [INSTR_SIZE-1:0] instruction_q;
    wire [6:0] V_dim;
    wire [6:0] U_dim;
    wire [6:0] ITER_dim;
    wire [6:0] V_dim1;
    wire [6:0] U_dim1;
    wire [6:0] ITER_dim1;
    wire [11:0] unified_buffer_addr_start_wr;
    wire [11:0] unified_buffer_addr_start_rd;


    instruction_queue instruction_queue 
                        (
                            .clk_i,
                            .rst_i,
                            .instruction_i,
                            .write_i(write_instruction_i),
                            .read_i('1),//(done_o),

                            .iq_full_o(instruction_queue_full_o),
                            .instruction_o(instruction_q)
                        );

    instruction_decode instruction_decoder 
                        (
                            .clk_i,
                            .rst_i,
                            .instruction_i(instruction_q),

                            .MAC_op_o(MAC_op),
                            .V_dim_o(V_dim),
                            .U_dim_o(U_dim),
                            .ITER_dim_o(ITER_dim),
                            .V_dim1_o(V_dim1),
                            .U_dim1_o(U_dim1),
                            .ITER_dim1_o(ITER_dim1),
                            .unified_buffer_addr_start_rd_o(unified_buffer_addr_start_wr),
                            .unified_buffer_addr_start_wr_o(unified_buffer_addr_start_wr) 
                        );

    MAC_systolic_array MAC_Array(   .clk_i,
                                    .rst_i,
                                    .stall_i(1'b0), 
                                    .load_weights_i(load_weights_to_MAC), 
                                    .compute_i(MAC_compute),
                                    .load_activations_i(load_activations_to_MAC),
                                    .mem_weight_i(MAC_weight_input),
                                    .mem_act_i(MAC_act_input),
                                    .compute_weight_sel_i(compute_weight_sel),

                                    .data_o(MAC_output)
                                    );

    unified_buffer Uni_Buf(     .clk_i,
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
                        //.HEIGHT,
                        //.WIDTH,

                        .data_o()//.data_o(unified_buffer_in)
                        );

    weight_fifo w_fifo( .clk_i,
                        .rst_i,
                        .read_en_i(load_weights_to_MAC[MUL_SIZE-1]),
                        .write_en_i(1'b1),
                        .data_i(weight_fifo_data_in),
                        .sending_data_i(sending_fifo_data_i),
                        
                        .fifo_full_o(weight_fifo_full),
                        .request_data_o(request_fifo_data_o),
                        .valid_o(weight_fifo_valid_output),
                        .data_o(MAC_weight_input)
                        );

    control_unit ctrl_unit( .clk_i,
                            .rst_i,
                            .MAC_op_i(MAC_op),
                            .weight_fifo_valid_output,
                            .V_dim_i(V_dim),
                            .U_dim_i(U_dim),
                            .ITER_dim_i(ITER_dim),
                            .V_dim1_i(V_dim1),
                            .U_dim1_i(U_dim1),
                            .ITER_dim1_i(ITER_dim1),
                            .unified_buffer_start_addr_rd_i(unified_buffer_addr_start_rd),

                            .compute_weight_sel_o(compute_weight_sel),
                            .compute_weights_buffered_o(compute_weights_buffered),
                            .compute_weights_rdy_o(compute_weights_rdy),
                            .next_weight_tile_o(next_weight_tile),
                            .unified_buffer_addr_rd_o(unified_buffer_addr_rd),
                            .load_weights_o(load_weights_to_MAC),
                            .load_activations_to_MAC_o(load_activations_to_MAC),
                            .stall_compute_o(stall_compute),
                            .MAC_compute_o(MAC_compute),
                            .read_accumulator_o(accumulator_read_enable),
                            .write_accumulator_o(accumulator_write_enable),
                            .accumulator_addr_wr_o(accumulator_addr_wr),
                            .accumulator_addr_rd_o(accumulator_addr_rd),
                            .accum_addr_mask_o(accum_addr_mask),
                            .accumulator_add_o(accumulator_add),
                            .unified_buffer_read_en_o(unified_buffer_read),
                            .done_o
                            );

endmodule
