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
                        input weight_fifo_valid_output,
                        input decoded_instr_t decoded_instruction_i,
                        input iq_empty_i,
                        
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
                        output logic [MUL_SIZE-1:0] accum_addr_mask_rd_o,
                        output logic accumulator_add_o,
                        output logic [MUL_SIZE-1:0] load_weights_o,
                        output logic unified_buffer_read_en_o,
                        output logic read_instruction_o,
                        output logic done_o
                    );

    // logic [2:0] MAC_op_i = decoded_instruction_i.MAC_op;
    // logic [7:0] V_dim_i = decoded_instruction_i.V_dim;
    // logic [7:0] U_dim_i = decoded_instruction_i.U_dim;
    // logic [7:0] ITER_dim_i = decoded_instruction_i.ITER_dim;
    // logic [6:0] V_dim1_i = decoded_instruction_i.V_dim1;
    // logic [6:0] U_dim1_i = decoded_instruction_i.U_dim1;
    // logic [6:0] ITER_dim1_i = decoded_instruction_i.ITER_dim1;
    // logic [11:0] unified_buffer_start_addr_rd_i = decoded_instruction_i.unified_buffer_addr_start_rd;
    // logic [11:0] unified_buffer_start_addr_wr_i = decoded_instruction_i.unified_buffer_addr_start_wr;

    wire invalidate_instruction_COMP;
    wire invalidate_instruction_ACCUM;
    wire invalidate_instruction_UNI;

    logic valid_instruction_WEIT;
    logic valid_instruction_COMP;
    logic valid_instruction_ACCUM;
    logic valid_instruction_UNI;

    decoded_instr_t instruction_WEIT;
    decoded_instr_t instruction_WEIT_UNI;
    decoded_instr_t instruction_UNI_COMP;
    decoded_instr_t instruction_COMP_ACCUM;

    initial valid_instruction_WEIT = '0;
    initial valid_instruction_ACCUM = '0;
    initial valid_instruction_COMP = '0;
    initial valid_instruction_UNI = '0;


    compute_control_unit comp_ctrl_unit(
                                        .clk_i,
                                        .rst_i,
                                        .instruction_i(instruction_UNI_COMP),
                                        .compute_weights_rdy_i(compute_weights_rdy_o),
                                        .instruction_valid_i(valid_instruction_COMP),

                                        //.read_instruction_o(read_decoded_instruction_o),
                                        .invalidate_instruction_o(invalidate_instruction_COMP),
                                        .compute_weight_sel_o,
                                        .load_activations_to_MAC_o,
                                        .stall_compute_o,
                                        .MAC_compute_o,
                                        .next_weight_tile_o
                                        );

    accumulator_control_unit accum_ctrl_unit(
                                        .clk_i,
                                        .rst_i,
                                        .instruction_i(instruction_COMP_ACCUM),
                                        .MAC_compute_i(MAC_compute_o),
                                        .load_activations_to_MAC_i(load_activations_to_MAC_o),
                                        .instruction_valid_i(valid_instruction_ACCUM),

                                        //.instruction_read_o(read_decoded_instruction_o),
                                        .invalidate_instruction_o(invalidate_instruction_ACCUM),
                                        .read_accumulator_o,
                                        .write_accumulator_o,
                                        .accumulator_addr_wr_o,
                                        .accumulator_addr_rd_o,
                                        .accum_addr_mask_o,
                                        .accum_addr_mask_rd_o,
                                        .accumulator_add_o,
                                        .done_o
                                        );

    weight_control_unit weight_ctrl_unit(   
                                            .clk_i,
                                            .rst_i,
                                            .instruction_i(decoded_instruction_i),
                                            .weight_fifo_valid_output,
                                            .next_weight_tile_i(next_weight_tile_o),
                                            .iq_empty_i,

                                            .read_instruction_o,
                                            .compute_weights_rdy_o,
                                            .compute_weights_buffered_o,
                                            .load_weights_o
                                        );

    unified_buffer_control_unit buf_ctrl(
                                    .clk_i,
                                    .rst_i,
                                    .compute_weights_rdy_i(compute_weights_rdy_o),
                                    .instruction_i(instruction_WEIT_UNI),
                                    .instruction_valid_i(valid_instruction_UNI),

                                    .invalidate_instruction_o(invalidate_instruction_UNI),
                                    .unified_buffer_read_en_o,
                                    .unified_buffer_addr_rd_o
                                    );

    always_ff @(posedge clk_i) begin
        valid_instruction_WEIT   <= ( read_instruction_o )              ? '1 : ( (!valid_instruction_UNI)   ? '0 : valid_instruction_WEIT );
        valid_instruction_UNI    <= ( invalidate_instruction_UNI )      ? '0 : ( (valid_instruction_WEIT)   ? '1 : valid_instruction_UNI );
        valid_instruction_COMP   <= ( invalidate_instruction_COMP )     ? '0 : ( (valid_instruction_UNI)    ? '1 : valid_instruction_COMP );
        valid_instruction_ACCUM  <= ( invalidate_instruction_ACCUM )    ? '0 : ( (valid_instruction_COMP)   ? '1 : valid_instruction_ACCUM );

        instruction_WEIT        <= ( read_instruction_o ) ? decoded_instruction_i : instruction_WEIT;
        instruction_WEIT_UNI    <= ( !valid_instruction_UNI ) ? instruction_WEIT : instruction_WEIT_UNI;
        instruction_UNI_COMP    <= ( !valid_instruction_COMP ) ? instruction_WEIT_UNI  : instruction_UNI_COMP;
        instruction_COMP_ACCUM  <= ( !valid_instruction_ACCUM ) ? instruction_UNI_COMP  : instruction_COMP_ACCUM;
    end
endmodule
