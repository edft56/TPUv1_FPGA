`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module compute_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input instruction_i,
                    input [8:0] H_DIM_i,
                    input [8:0] W_DIM_i,
                    input compute_weights_rdy_i,
                    input compute_weights_buffered_i,
                    input [11:0] unified_buffer_start_addr_rd_i,

                    output logic [MUL_SIZE-1 : 0] compute_weight_sel_o [MUL_SIZE],
                    //output logic [11:0] unified_buffer_addr_rd_o,
                    output logic load_activations_to_MAC_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic next_weight_tile_o
                    );

    enum logic [1:0] {STALL, LOAD_ACTIVATIONS, COMPUTE, COMPUTE_WEIGHT_CHANGE} compute_state;

    logic [ 5:0] weight_change_cntr_q;
    logic [ 9:0] compute_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    logic [ 3:0] weight_tiles_x_consumed_q;
    logic [ 3:0] weight_tiles_y_consumed_q;
    logic [ 3:0] weight_tiles_x_consumed;
    logic [ 3:0] weight_tiles_y_consumed;


    logic [ 9:0] next_compute_cntr;
    logic        done_compute;
    //logic        next_weight_tile;
    logic        done_weight_tiles_y;
    logic        done_weight_tiles_x;
    logic [11:0] unified_buffer_addr_rd;

    logic [2*MUL_SIZE-1 : 0] xor_value;
    logic [ 5:0] next_weight_change_cntr;
    logic wait_act_q;

    initial compute_state = STALL;
    initial weight_change_cntr_q = 0;
    initial compute_cntr_q = 0;
    initial weight_tiles_x_consumed_q = 0;
    initial weight_tiles_y_consumed_q = 0;
    initial next_compute_cntr = 0;
    initial compute_weight_sel_o = '{default:'0};
    initial wait_act_q = 0;

    always_comb begin
        next_weight_tile_o = compute_cntr_q == H_DIM_i;

        done_weight_tiles_y = (weight_tiles_y_consumed_q == 4'(H_DIM_i>>5)) & next_weight_tile_o;
        done_weight_tiles_x = (weight_tiles_x_consumed_q == 4'(W_DIM_i>>5)) & done_weight_tiles_y;

        weight_tiles_y_consumed = (done_weight_tiles_y) ? '0 : ( next_weight_tile_o    ? weight_tiles_y_consumed_q + 1 : weight_tiles_y_consumed_q );
        weight_tiles_x_consumed = (done_weight_tiles_x) ? '0 : ( done_weight_tiles_y ? weight_tiles_x_consumed_q + 1 : weight_tiles_x_consumed_q );

        next_compute_cntr = (next_weight_tile_o) ? '0 : compute_cntr_q + 1;

        // if(next_weight_tile_o) unified_buffer_addr_rd = unified_buffer_start_addr_rd_i + (weight_tiles_y_consumed)*(((H_DIM_i>>5)+1)<<5);
        // else if (compute_state == LOAD_ACTIVATIONS | compute_state == COMPUTE) unified_buffer_addr_rd = unified_buffer_addr_rd_o + 1;
        // else unified_buffer_addr_rd = unified_buffer_start_addr_rd_i + weight_tiles_y_consumed_q*(((H_DIM_i>>5)+1)<<5);

        // unified_buffer_addr_rd = (unified_buffer_addr_rd_o == H_DIM_i) ?
        //                           unified_buffer_start_addr_rd_i + (weight_tiles_x_consumed+1)*(((H_DIM_i>>5)+1)<<5) : 
        //                           ( (compute_state != STALL) ? unified_buffer_addr_rd_o + 1 : unified_buffer_addr_rd_o);

        //unified_buffer_addr_rd = (compute_state == LOAD_ACTIVATIONS | compute_state == COMPUTE) ? unified_buffer_addr_rd_o + 1 : unified_buffer_start_addr_rd_i + weight_tiles_y_consumed_q*(((H_DIM_i>>5)+1)<<5);

        done_compute            = done_weight_tiles_x;
        next_weight_change_cntr = weight_change_cntr_q + 1;
        xor_value               = (64'h8000000000000000 >> next_weight_change_cntr);
    end
    

    always_ff @( posedge clk_i ) begin
        //done_o                   <= 1'b0;

        //assume tiles are written to unified buffer in the required order. assume read is disabled during reverse partial state.
        // unified_buffer_addr_rd_o <= unified_buffer_addr_rd;

        weight_tiles_y_consumed_q <= weight_tiles_y_consumed;
        weight_tiles_x_consumed_q <= weight_tiles_x_consumed;

        case(compute_state)
            STALL: begin
                load_activations_to_MAC_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                MAC_compute_o           <= 1'b0;
                

                if (instruction_i & compute_weights_rdy_i) begin
                    load_activations_to_MAC_o  <= 1'b1;
                    compute_state       <= LOAD_ACTIVATIONS;
                    for(int i=0; i<32; i++) begin
                        compute_weight_sel_o[i] <= ~compute_weight_sel_o[i];
                    end
                end
            end
            LOAD_ACTIVATIONS: begin
                load_activations_to_MAC_o      <= 1'b1;
                stall_compute_o         <= 1'b1;
                MAC_compute_o           <= 1'b0;
                
                //compute_state <= COMPUTE;
                wait_act_q <= '1;

                if(wait_act_q) begin
                    compute_state <= COMPUTE;
                    wait_act_q <= '0;
                end
            end
            COMPUTE: begin
                load_activations_to_MAC_o          <= 1'b1;
                stall_compute_o             <= 1'b0;
                MAC_compute_o               <= 1'b1;

                compute_cntr_q              <= next_compute_cntr;

                if(compute_weights_rdy_i == '0) begin
                    compute_state           <= STALL;
                    stall_compute_o         <= 1'b1;
                    MAC_compute_o           <= 1'b0;
                end

                if(done_compute) begin
                    //done_o                  <= 1'b1;
                    compute_state           <= STALL;
                end
                if(compute_cntr_q == H_DIM_i) begin
                    compute_state           <= COMPUTE_WEIGHT_CHANGE;
                    compute_weight_sel_o[0] <= compute_weight_sel_o[0] ^ (32'h80000000);
                    weight_change_cntr_q    <= weight_change_cntr_q + 1;
                    compute_cntr_q          <= '0;
                end
            end
            COMPUTE_WEIGHT_CHANGE: begin
                weight_change_cntr_q        <= weight_change_cntr_q + 1;

                compute_cntr_q              <= next_compute_cntr;

                compute_weight_sel_o[0]     <= compute_weight_sel_o[0] ^ (32'h80000000 >> weight_change_cntr_q);
                compute_weight_sel_o[1:31]  <= compute_weight_sel_o[0:30];
                

                if(weight_change_cntr_q == (MUL_SIZE<<2)-1) begin
                    compute_state           <= COMPUTE;
                end
            end
            default: begin
            end

        endcase
        
    end
endmodule
