`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module accumulator_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    //input [8:0] H_DIM_i,
                    //input [8:0] W_DIM_i,
                    input [6:0] V_dim_i,
                    input [6:0] U_dim_i,
                    input MAC_compute_i,
                    input load_activations_to_MAC_i,

                    
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [9:0] accumulator_addr_wr_o,
                    output logic [9:0] accumulator_addr_rd_o,
                    output logic [MUL_SIZE-1:0] accum_addr_mask_o,
                    output logic accumulator_add_o,
                    output logic done_o
                    );


    enum logic [2:0] {STALL, NO_OUTPUT, PARTIAL_OUTPUT, FULL_OUTPUT, REVERSE_PARTIAL} accum_output_state;


    logic [ 9:0] accum_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    

    logic [8:0] upper_bound;

    initial accum_output_state = STALL;
    
    initial accum_cntr_q = 0;
    initial accumulator_add_o = 0;

    

    always_comb begin
        //next_accum_cntr = (next_weight_tile_o) ? '0 : accum_cntr_q + 1;

        upper_bound = ( (V_dim_i>>5) * (U_dim_i>>5) ) << 5;
    end
    

    always_ff @( posedge clk_i ) begin
        done_o <= '0;
        
        case (accum_output_state)
            STALL: begin
                if(load_activations_to_MAC_i) begin
                    accum_output_state <= NO_OUTPUT;
                    accum_cntr_q <= accum_cntr_q + 1;
                end
            end
            NO_OUTPUT: begin
                accumulator_addr_rd_o   <= '0;
                accumulator_addr_wr_o   <= '0;
                accum_addr_mask_o       <= '0;
                write_accumulator_o     <= '0;

                accum_cntr_q <= accum_cntr_q + 1;

                if(accum_cntr_q[4:0] == (MUL_SIZE-1)) begin
                    accum_cntr_q          <= '0;
                    accum_output_state    <= PARTIAL_OUTPUT;
                end
            end
            PARTIAL_OUTPUT: begin
                write_accumulator_o     <= 1'b1;

                accumulator_addr_wr_o   <= accum_cntr_q;
                accum_addr_mask_o       <= signed'(signed'(32'h80000000)>>>accum_cntr_q);

                accum_cntr_q <= accum_cntr_q + 1;

                if (accum_cntr_q == (MUL_SIZE-1)) begin
                    accum_output_state <= FULL_OUTPUT;
                end
            end
            FULL_OUTPUT: begin
                write_accumulator_o     <= 1'b1;
                accum_addr_mask_o       <= '1;

                accumulator_add_o       <= (accum_cntr_q + 1 > upper_bound) ? '1 : '0;
                read_accumulator_o      <= (accum_cntr_q + 1 > upper_bound) ? '1 : '0;

                accumulator_addr_rd_o   <= (accum_cntr_q + 1 > upper_bound) ? accumulator_addr_rd_o + 1 : '0;
                accumulator_addr_wr_o   <= accum_cntr_q;

                accum_cntr_q <= accum_cntr_q + 1;

                if(accumulator_addr_rd_o + 1 == upper_bound) begin
                    accum_output_state <= REVERSE_PARTIAL;
                end
            end
            REVERSE_PARTIAL: begin
                write_accumulator_o     <= 1'b1;

                accumulator_addr_rd_o   <= (accum_cntr_q + 1 > upper_bound) ? accumulator_addr_rd_o + 1 : '0;
                accumulator_addr_wr_o   <= accum_cntr_q;
                accum_addr_mask_o       <= (32'h7FFFFFFF)>>rev_partial_cntr_q;

                rev_partial_cntr_q      <= rev_partial_cntr_q + 1;
                accum_cntr_q            <= accum_cntr_q + 1;

                if (rev_partial_cntr_q == MUL_SIZE-1) begin
                    accum_output_state  <= STALL;
                    done_o              <= '1;
                end
            end
            default: begin

            end
        endcase
        

    end
endmodule
