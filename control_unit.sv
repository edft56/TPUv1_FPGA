`timescale 1ns/1ns

//`include "packages.sv"

module control_unit(input clk_i,rst_i,
                    input instruction_i,
                    //input next_weight_tile_rdy_i,
                    input activations_rdy_i,
                    input weight_fifo_valid_output,
                    input logic [6:0] accumulator_start_addr_wr_i,

                    output logic load_weights_o,
                    output logic load_activations_o,
                    output logic stall_compute_o,
                    output logic MAC_compute_o,
                    output logic read_accumulator_o,
                    output logic write_accumulator_o,
                    output logic [6:0] accumulator_addr_wr_o,
                    output logic done_o,
                    output Acc_types::acc_rd_mode accumulator_read_mode
                    );
    import Acc_types::*;

    enum logic [1:0] {STALL, LOAD_WEIGHTS, LOAD_ACTIVATIONS, COMPUTE} state;

    logic [4:0] load_weights_cntr_q;
    logic [5:0] compute_time_q;


    initial state = STALL;
    
    always_ff @( posedge clk_i ) begin
        done_o                  <= 1'b0;
        case(state)
            STALL: begin
                accumulator_read_mode   <= NORMAL;
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
                accumulator_read_mode   <= NORMAL;
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
                accumulator_read_mode   <= NORMAL;
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
                accumulator_read_mode   <= DIAG;
                load_activations_o      <= 1'b1;
                stall_compute_o         <= 1'b0;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b1;

                compute_time_q <= compute_time_q + 1;
                if (compute_time_q > 6'd31) begin
                    write_accumulator_o <= 1'b1;
                    accumulator_addr_wr_o <= compute_time_q - accumulator_start_addr_wr_i;
                end
                if (compute_time_q == 6'd63) begin
                    //accumulator_read_mode <= DIAG;
                    read_accumulator_o <= 1'b1;
                    state <= STALL;
                    done_o <= 1'b1;
                end
            end
            default: begin
                accumulator_read_mode   <= NORMAL;
                load_activations_o      <= 1'b0;
                stall_compute_o         <= 1'b1;
                load_weights_o          <= 1'b0;
                read_accumulator_o      <= 1'b0;
                MAC_compute_o           <= 1'b0;
            end

        endcase
        

    end
endmodule
