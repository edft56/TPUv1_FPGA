`timescale 1ns/1ns

//`include "packages.sv"

module control_unit(input clk_i,rst_i,
                    input instruction_i,
                    //input next_weight_tile_rdy_i,
                    input activations_rdy_i,
                    input weight_fifo_valid_output,
                    input logic [6:0] accumulator_start_addr_wr_i,
                    input logic [15:0] lines_to_compute_i,

                    output logic load_weights_o,
                    output logic load_activations_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [6:0] accumulator_addr_wr_o,
                    output logic [31:0] accum_addr_mask_o,
                    output logic done_o
                    );

    enum logic [1:0] {STALL, LOAD_WEIGHTS, LOAD_ACTIVATIONS, COMPUTE} state;

    enum logic {NON_FULL_OUTPUT, FULL_OUTPUT} accum_addr_mask_state;

    logic [ 4:0] load_weights_cntr_q;
    logic [ 5:0] compute_time_q;
    logic [15:0] lines_computed_q;

    initial compute_time_q = 0;
    initial lines_computed_q = 1;
    initial state = STALL;
    initial accum_addr_mask_state = NON_FULL_OUTPUT;
    
    always_ff @( posedge clk_i ) begin
        done_o                  <= 1'b0;
        case(state)
            STALL: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
                

                if (instruction_i) begin
                    state <= LOAD_WEIGHTS;
                end
            end
            LOAD_WEIGHTS: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b1;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;

                load_weights_cntr_q <= (weight_fifo_valid_output) ? load_weights_cntr_q + 1 : load_weights_cntr_q;
                if (load_weights_cntr_q == 5'd31) begin
                    state <= LOAD_ACTIVATIONS;
                end
            end
            LOAD_ACTIVATIONS: begin
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b1;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;

                if (activations_rdy_i == 1'b1) begin
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b0;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b1;

                compute_time_q <= compute_time_q + 1;
                
                case(accum_addr_mask_state)
                    NON_FULL_OUTPUT: begin
                        accumulator_addr_wr_o   <= accumulator_start_addr_wr_i;
                        accum_addr_mask_o       <= (compute_time_q > 'd31) ? signed'(signed'(32'h80000000)>>>compute_time_q[4:0]) : '0;
                        write_accumulator_o     <= (compute_time_q > 'd31) ? 1'b1 : 1'b0;

                        if (compute_time_q == 'd63) begin
                            accum_addr_mask_state <= FULL_OUTPUT;
                        end
                    end
                    FULL_OUTPUT: begin
                        lines_computed_q        <= lines_computed_q + 1;
                        accum_addr_mask_o       <= '1;
                        accumulator_addr_wr_o   <= accumulator_start_addr_wr_i + lines_computed_q;
                        write_accumulator_o     <= 1'b1;

                        if(lines_computed_q == lines_to_compute_i) begin
                            done_o <= 1'b1;
                            state <= STALL;
                            write_accumulator_o     <= 1'b0;
                        end
                    end
                endcase
                
            end
            default: begin
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
            end

        endcase
        

    end
endmodule


// module compute_state_control(   input clk_i,
//                                 input logic [ 6:0] accumulator_start_addr_wr_i,
//                                 input logic [15:0] lines_to_compute_i,
//                                 input logic [ 1:0] state_i,

//                                 output logic [31:0] accum_addr_mask_o,
//                                 output logic [ 6:0] accumulator_addr_wr_o,
//                                 output logic        write_accumulator_o,
//                                 output logic        done_o
//                             );

//     enum logic {NON_FULL_OUTPUT, FULL_OUTPUT} accum_addr_mask_state;

//     logic [ 5:0] compute_time_q;
//     logic [15:0] lines_computed_q;

//     initial compute_time_q=0;
//     initial lines_computed_q=1;

//     always_ff @( posedge clk_i ) begin
            
//         case(accum_addr_mask_state)
//             NON_FULL_OUTPUT: begin
//                 accumulator_addr_wr_o   <= accumulator_start_addr_wr_i;
//                 accum_addr_mask_o       <= (compute_time_q > 'd31) ? 32'h8000>>>compute_time_q[4:0] : '0;
//                 write_accumulator_o     <= (compute_time_q > 'd31) ? 1'b1 : 1'b0;

//                 if (compute_time_q == 'd63) begin
//                     accum_addr_mask_state <= FULL_OUTPUT;
//                 end
//             end
//             FULL_OUTPUT: begin
//                 lines_computed_q        <= lines_computed_q + 1;
//                 accum_addr_mask_o       <= '1;
//                 accumulator_addr_wr_o   <= accumulator_start_addr_wr_i + lines_computed_q;
//                 write_accumulator_o     <= 1'b1;

//                 if(lines_computed_q == lines_to_compute_i) begin
//                     done_o <= 1'b1;
//                     state <= STALL;
//                 end
//             end
//         endcase

//     end
// endmodule


