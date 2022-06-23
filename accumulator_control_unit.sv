`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


module accumulator_control_unit
                    import tpu_package::*;    
                  (input clk_i,rst_i,
                    input [2:0] MAC_op_i,
                    //input [8:0] H_DIM_i,
                    //input [8:0] W_DIM_i,
                    input [7:0] V_dim_i,
                    input [7:0] U_dim_i,
                    input MAC_compute_i,
                    input load_activations_to_MAC_i,

                    output logic instruction_read_o,
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [9:0] accumulator_addr_wr_o,
                    output logic [9:0] accumulator_addr_rd_o,
                    output logic [MUL_SIZE-1:0] accum_addr_mask_o,
                    output logic [MUL_SIZE-1:0] accum_addr_mask_rd_o,
                    output logic accumulator_add_o,
                    output logic done_o
                    );


    enum logic [2:0] {RESET, STALL, NO_OUTPUT, PARTIAL_OUTPUT, FULL_OUTPUT, REVERSE_PARTIAL, REVERSE_PARTIAL_CONTINUE} accum_output_state;

    logic [7:0] U_dim_q;
    logic [7:0] V_dim_q;

    logic [ 9:0] accum_cntr_q;
    logic [ 5:0] rev_partial_cntr_q;
    logic [ 2:0] tile_x_q;

    logic [ 2:0] max_tiles_x;
    logic [ 9:0] upper_bound;

    initial accum_output_state = RESET;
    initial tile_x_q = 0;
    initial accum_cntr_q = 0;
    initial accumulator_add_o = 0;

    

    always_comb begin
        //next_accum_cntr = (next_weight_tile_o) ? '0 : accum_cntr_q + 1;
        max_tiles_x = U_dim_q >> 5;
        upper_bound = (15'( (V_dim_q) * (U_dim_q) ) >> 5);
    end
    

    always_ff @( posedge clk_i ) begin
        done_o              <= '0;
        instruction_read_o  <= (instruction_read_o) ? '0 : instruction_read_o;
        
        case (accum_output_state)
            RESET: begin    
                accum_cntr_q            <= '0;
                rev_partial_cntr_q      <= '0;
                accumulator_add_o       <= '0;
                done_o                  <= '0;
                accum_addr_mask_o       <= '0;
                accumulator_addr_wr_o   <= '0;
                accumulator_addr_rd_o   <= '0;
                write_accumulator_o     <= '0;
                read_accumulator_o      <= '0;
                accum_addr_mask_rd_o    <= 32'h80000000;
                tile_x_q                <= '0;

                if (MAC_op_i[1]) begin
                    accum_output_state      <= STALL;
                    U_dim_q                 <= U_dim_i;
                    V_dim_q                 <= V_dim_i;
                    instruction_read_o      <= '1;
                end
            end 
            STALL: begin

                if(load_activations_to_MAC_i) begin
                    accum_output_state  <= NO_OUTPUT;
                    accum_cntr_q        <= accum_cntr_q + 1;
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

                if (accum_cntr_q == (MUL_SIZE-1) | accum_cntr_q + 1 == V_dim_q) begin
                    if( (accum_cntr_q + 1) == V_dim_q & (tile_x_q + 1 == max_tiles_x) ) begin
                        accum_output_state <= REVERSE_PARTIAL;
                        accum_addr_mask_rd_o    <= (32'h7FFFFFFF)>>rev_partial_cntr_q;
                    end
                    else begin
                        accum_output_state <= FULL_OUTPUT;
                    end
                end
            end
            FULL_OUTPUT: begin
                write_accumulator_o     <= 1'b1;
                accum_addr_mask_o       <= '1;

                tile_x_q <= (accum_cntr_q + 1 == upper_bound) ? tile_x_q + 1 : tile_x_q;

                accumulator_add_o       <= (accum_cntr_q + 1 == upper_bound & !(tile_x_q + 1 == max_tiles_x)) ? '1 : accumulator_add_o;
                read_accumulator_o      <= (accum_cntr_q + 1 == upper_bound & !(tile_x_q + 1 == max_tiles_x)) ? '1 : read_accumulator_o;

                accumulator_addr_rd_o   <= (accum_cntr_q + 1 == upper_bound) ? '0 : accum_cntr_q + 1;
                accumulator_addr_wr_o   <= accum_cntr_q;


                accum_addr_mask_rd_o <= ( ((accum_cntr_q + 1 == upper_bound & tile_x_q =='0) | tile_x_q == 'd1) & accum_addr_mask_rd_o != '1 ) ? signed'(signed'(32'h80000000)>>>((accum_cntr_q + 1 == upper_bound) ? '0 : accum_cntr_q + 1)) : accum_addr_mask_rd_o;

                accum_cntr_q <= (accum_cntr_q + 1 == upper_bound) ? '0 : accum_cntr_q + 1;

                if( (accum_cntr_q + 1 == upper_bound) & (tile_x_q + 1 == max_tiles_x) ) begin
                    if(MAC_op_i[1]) begin
                        //accum_cntr_q            <= '0; //needs to select the 2nd accum
                        accum_addr_mask_o       <= '0;
                        accum_addr_mask_rd_o    <= 32'h80000000;
                        tile_x_q                <= '0;
                        instruction_read_o      <= '1;

                        accum_output_state      <= REVERSE_PARTIAL_CONTINUE;
                        accum_addr_mask_rd_o    <= (32'h7FFFFFFF)>>rev_partial_cntr_q;
                    end
                    else begin
                        accum_output_state      <= REVERSE_PARTIAL;
                        accum_addr_mask_rd_o    <= (32'h7FFFFFFF)>>rev_partial_cntr_q;
                    end
                end
            end
            REVERSE_PARTIAL: begin
                write_accumulator_o     <= 1'b1;

                //accumulator_addr_rd_o   <= (accum_cntr_q + 1 > upper_bound) ? accumulator_addr_rd_o + 1 : '0;
                accumulator_addr_wr_o   <= accum_cntr_q;
                accum_addr_mask_o       <= accum_addr_mask_rd_o;

                accum_addr_mask_rd_o    <= (32'h7FFFFFFF)>>rev_partial_cntr_q + 1;

                rev_partial_cntr_q      <= rev_partial_cntr_q + 1;
                accum_cntr_q            <= accum_cntr_q + 1;

                if (rev_partial_cntr_q == MUL_SIZE-1) begin
                    accum_output_state  <= RESET;
                    done_o              <= '1;
                end
            end
            REVERSE_PARTIAL_CONTINUE: begin //its like reverse partial for prev instruction but also computes new instruction
                write_accumulator_o     <= 1'b1;

                accumulator_addr_wr_o   <= accum_cntr_q;

                accum_addr_mask_rd_o    <= (32'h7FFFFFFF)>>rev_partial_cntr_q + 1;

                rev_partial_cntr_q      <= rev_partial_cntr_q + 1;
                accum_cntr_q            <= accum_cntr_q + 1;

                if (rev_partial_cntr_q == MUL_SIZE-1) begin
                    accum_output_state  <= FULL_OUTPUT;
                end
            end
            default: begin

            end
        endcase
        

    end
endmodule

