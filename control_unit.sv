`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module control_unit 
                    import tpu_package::*;    
                    (
                        input clk_i,
                        input rst_i,
                        input instruction_i,
                        input [8:0] H_DIM_i,
                        input [8:0] W_DIM_i,
                        input [8:0] HEIGHT,
                        input [8:0] WIDTH,
                        input weight_fifo_valid_output,
                        input [11:0] unified_buffer_start_addr_rd_i,
                        
                        output [MUL_SIZE-1 : 0] compute_weight_sel_o [MUL_SIZE],
                        output compute_weights_buffered_o,
                        output compute_weights_rdy_o,
                        output next_weight_tile_o,
                        output logic [11:0] unified_buffer_addr_rd_o,
                        output logic load_activations_to_MAC_o,
                        output logic stall_compute_o,
                        output logic MAC_compute_o,
                        output logic read_accumulator_o,
                        output logic write_accumulator_o,
                        output logic [9:0] accumulator_addr_wr_o,
                        output logic [9:0] accumulator_addr_rd_o,
                        output logic [MUL_SIZE-1:0] accum_addr_mask_o,
                        output logic accumulator_add_o,
                        output logic [MUL_SIZE-1:0] load_weights_o,
                        output logic unified_buffer_read_en_o,
                        output logic done_o
                    );

    compute_control_unit comp_ctrl_unit(
                                        .clk_i,
                                        .rst_i,
                                        .instruction_i,
                                        .H_DIM_i,
                                        .W_DIM_i,
                                        .compute_weights_rdy_i(compute_weights_rdy_o),
                                        .compute_weights_buffered_i(compute_weights_buffered_o),
                                        .unified_buffer_start_addr_rd_i,

                                        .compute_weight_sel_o,
                                        //.unified_buffer_addr_rd_o,
                                        .load_activations_to_MAC_o,
                                        .stall_compute_o,
                                        .MAC_compute_o,
                                        .next_weight_tile_o
                                        );

    accumulator_control_unit accum_ctrl_unit(
                                        .clk_i,
                                        .rst_i,
                                        .H_DIM_i,
                                        .W_DIM_i,
                                        .HEIGHT,
                                        .WIDTH,
                                        .compute_weights_rdy_i(compute_weights_rdy_o),
                                        .compute_weights_buffered_i(compute_weights_buffered_o),
                                        .MAC_compute_i(MAC_compute_o),
                                        .load_activations_to_MAC_i(load_activations_to_MAC_o),

                                        .read_accumulator_o,
                                        .write_accumulator_o,
                                        .accumulator_addr_wr_o,
                                        .accumulator_addr_rd_o,
                                        .accum_addr_mask_o,
                                        .accumulator_add_o,
                                        .done_o
                                        );

    weight_control_unit weight_ctrl_unit(   
                                            .clk_i,
                                            .rst_i,
                                            .instruction_i,
                                            .weight_fifo_valid_output,
                                            .next_weight_tile_i(next_weight_tile_o),
                                            .done_i(done_o),

                                            .compute_weights_rdy_o,
                                            .compute_weights_buffered_o,
                                            .load_weights_o
                                        );

    unified_buffer_control_unit buf_ctrl(
                                    .clk_i,
                                    .rst_i,
                                    .instruction_i,
                                    .compute_weights_rdy_i(compute_weights_rdy_o),
                                    .H_DIM_i,
                                    .W_DIM_i,
                                    .unified_buffer_start_addr_rd_i,

                                    .unified_buffer_read_en_o,
                                    .unified_buffer_addr_rd_o
                                    );

endmodule
