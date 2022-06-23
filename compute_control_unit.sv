`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module compute_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input [2:0] MAC_op_i,
                    input [6:0] V_dim1_i,
                    input [7:0] U_dim_i,
                    //input [8:0] W_DIM_i,
                    input compute_weights_rdy_i,

                    //output logic read_instruction_o,
                    output logic [MUL_SIZE-1 : 0] compute_weight_sel_o [MUL_SIZE],
                    output logic load_activations_to_MAC_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic next_weight_tile_o
                    );

    enum logic [2:0] {RESET, STALL, LOAD_ACTIVATIONS, COMPUTE, COMPUTE_WEIGHT_CHANGE} compute_state;

    logic [ 5:0] weight_change_cntr_q;
    logic [ 9:0] compute_cntr_q;
    logic [ 2:0] current_weight_tile_q;
    logic        wait_act_q;
    logic [ 7:0] U_dim_q;
    logic [ 6:0] V_dim1_q;

    logic [ 9:0] next_compute_cntr;
    logic        done_compute;
    logic [ 2:0] max_tiles_x;


    initial compute_state               = RESET;
    initial weight_change_cntr_q        = '0;
    initial compute_cntr_q              = '0;
    initial load_activations_to_MAC_o   = '0;
    initial stall_compute_o             = '1;
    initial MAC_compute_o               = '0;
    initial compute_weight_sel_o        = '{default:'0};
    initial wait_act_q                  = '0;
    initial current_weight_tile_q       = '0;

    always_comb begin
        next_weight_tile_o  = compute_cntr_q == V_dim1_q;
        max_tiles_x         = U_dim_q >> 5;

        //next_compute_cntr = (next_weight_tile_o) ? '0 : compute_cntr_q + 1;

        done_compute            = (current_weight_tile_q + 1 == max_tiles_x) & next_weight_tile_o;
    end
    

    always_ff @( posedge clk_i ) begin
        //done_o                   <= 1'b0;
        current_weight_tile_q       <= (done_compute) ? '0 : (next_weight_tile_o) ? current_weight_tile_q + 1 : current_weight_tile_q;
        //read_instruction_o          <= (compute_state == RESET) ? '1 : done_compute;

        case(compute_state)
            RESET: begin
                load_activations_to_MAC_o   <= '0;
                stall_compute_o             <= '1;
                MAC_compute_o               <= '0;
                wait_act_q                  <= '0;
                compute_cntr_q              <= '0;
                compute_weight_sel_o        <= '{default:'0};
                weight_change_cntr_q        <= '0;
                current_weight_tile_q       <= '0;
                
                
                if (MAC_op_i[1]) begin
                    compute_state           <= STALL;
                    U_dim_q                 <= U_dim_i;
                    V_dim1_q                <= V_dim1_i;
                end
            end
            STALL: begin
                load_activations_to_MAC_o   <= 1'b0;
                stall_compute_o             <= 1'b1;
                MAC_compute_o               <= 1'b0;
                

                if (compute_weights_rdy_i) begin
                    load_activations_to_MAC_o   <= 1'b1;
                    compute_state               <= LOAD_ACTIVATIONS;
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
                wait_act_q <= 1;

                if(wait_act_q) begin
                    compute_state <= COMPUTE;
                    wait_act_q <= '0;
                    compute_cntr_q              <= compute_cntr_q + 1;
                end
            end
            COMPUTE: begin
                load_activations_to_MAC_o          <= 1'b1;
                stall_compute_o             <= 1'b0;
                MAC_compute_o               <= 1'b1;

                compute_cntr_q              <= compute_cntr_q + 1;

                if(compute_weights_rdy_i == '0) begin
                    compute_state           <= STALL;
                    stall_compute_o         <= 1'b1;
                    MAC_compute_o           <= 1'b0;
                end

                if(next_weight_tile_o & !done_compute) begin
                    compute_state           <= COMPUTE_WEIGHT_CHANGE;
                    compute_weight_sel_o[0] <= compute_weight_sel_o[0] ^ (32'h80000000);
                    weight_change_cntr_q    <= weight_change_cntr_q + 1;
                    compute_cntr_q          <= '0;
                end
            end
            COMPUTE_WEIGHT_CHANGE: begin
                weight_change_cntr_q        <= weight_change_cntr_q + 1;

                compute_cntr_q              <= compute_cntr_q + 1;

                compute_weight_sel_o[0]     <= compute_weight_sel_o[0] ^ (32'h80000000 >> weight_change_cntr_q);
                compute_weight_sel_o[1:31]  <= compute_weight_sel_o[0:30];
                

                if(weight_change_cntr_q == (MUL_SIZE*2)-1) begin
                    compute_state           <= COMPUTE;
                end
            end
            default: begin
            end

        endcase

        if(done_compute) begin
            //done_o                  <= 1'b1;
            if (MAC_op_i[1]) begin
                compute_state               <= COMPUTE_WEIGHT_CHANGE;
                compute_cntr_q              <= '0;
                weight_change_cntr_q        <= weight_change_cntr_q + 1;
                compute_weight_sel_o[0]     <= compute_weight_sel_o[0] ^ (32'h80000000);
                current_weight_tile_q       <= '0;
            end
            else compute_state              <= RESET;
        end
        
    end
endmodule
