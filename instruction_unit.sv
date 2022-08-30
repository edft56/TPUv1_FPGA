`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard


//assume inputs are registered for now
//otherwise will need to add almost_empty and almost_full signals due to latency
module instruction_unit
                        import tpu_package::*;    
                        (
                            input  clk_i,rstN_i,
                            input [INSTR_SIZE-1:0] instruction_i,
                            input  write_i,
                            input  read_i,

                            output logic iq_empty_o,
                            output logic iq_full_o,
                            decoded_instr_t decoded_instruction_o
                        );

    typedef enum logic [1:0] {
                                RESET,
                                EMPTY,
                                STEADY,
                                FULL
                                } iq_states_t;

    iq_states_t iq_state, next_iq_state;

    decoded_instr_t decoded_instruction_fifo[32];

    logic [4:0] read_idx_q;
    logic [4:0] write_idx_q;     

    logic [4:0] next_read_idx;
    logic [4:0] next_write_idx;

    initial read_idx_q  = '0;
    initial write_idx_q = '0;
    initial iq_state    = RESET;
    initial iq_empty_o  = '1;
    initial iq_full_o   = '0;

    always_comb begin
        next_read_idx  = (read_i) ? read_idx_q + 1 : read_idx_q;
        next_write_idx = (write_i) ? write_idx_q + 1 : write_idx_q;
    end

    always_ff @( posedge clk_i, negedge rstN_i ) begin
        if(rstN_i)  iq_state = RESET;
        else        iq_state = next_iq_state;
    end

    always_comb begin
        case(iq_state)
            RESET: begin
                next_iq_state = EMPTY;
            end
            EMPTY: begin
                next_iq_state = (write_i) ? STEADY : EMPTY;
            end
            STEADY: begin
                next_iq_state =  ( write_i & next_write_idx == next_read_idx) ? FULL :
                                 ( (read_i & next_write_idx == next_read_idx) ? EMPTY : STEADY );
            end
            FULL: begin
                next_iq_state = (read_i) ? STEADY : FULL;
            end
        endcase
    end

    always_ff @( posedge clk_i ) begin
        decoded_instruction_o           <= decoded_instruction_fifo[read_idx_q];

        case({write_i,instruction_i[ 3: 0]})
            5'b10001: begin
                decoded_instruction_fifo[write_idx_q].MAC_op                        <= 3'b010;
                decoded_instruction_fifo[write_idx_q].V_dim                         <= instruction_i[11: 4];
                decoded_instruction_fifo[write_idx_q].U_dim                         <= instruction_i[19:12];
                decoded_instruction_fifo[write_idx_q].ITER_dim                      <= instruction_i[27:20];
                decoded_instruction_fifo[write_idx_q].unified_buffer_start_addr_rd  <= instruction_i[39:28];
                decoded_instruction_fifo[write_idx_q].unified_buffer_start_addr_wr  <= instruction_i[51:40];

                decoded_instruction_fifo[write_idx_q].V_dim1                        <= instruction_i[11: 4] - 1;
                decoded_instruction_fifo[write_idx_q].U_dim1                        <= instruction_i[19:12] - 1;
                decoded_instruction_fifo[write_idx_q].ITER_dim1                     <= instruction_i[27:20] - 1;
            end
            default: begin
            end
        endcase

        case(iq_state)
            RESET: begin
                iq_empty_o  <= '1;
                iq_full_o   <= '1;
                write_idx_q <= '0;
                read_idx_q  <= '0;
            end
            EMPTY: begin
                write_idx_q <= next_write_idx;
                //read_idx_q  <= next_read_idx;

                iq_empty_o  <= '1;
                
                if (write_i) begin
                    iq_empty_o  <= '0;
                end
            end
            STEADY: begin
                write_idx_q <= next_write_idx;
                read_idx_q  <= next_read_idx;
        
                if ( write_i & next_write_idx == next_read_idx) begin
                    iq_full_o  <= '1;
                end

                if ( read_i & next_write_idx == next_read_idx) begin
                    iq_empty_o  <= '1;
                end
            
            end
            FULL: begin
                //write_idx_q <= next_write_idx;
                read_idx_q  <= next_read_idx;

                iq_full_o <= '1;
                
                if (read_i) begin
                    iq_full_o <= '0;
                end
            end
        endcase
        
    end




    // always_ff @( posedge clk_i ) begin
    //     decoded_instruction_o           <= decoded_instruction_fifo[read_idx_q];

    //     case({write_i,instruction_i[ 3: 0]})
    //         5'b10001: begin
    //             decoded_instruction_fifo[write_idx_q].MAC_op                        <= 3'b010;
    //             decoded_instruction_fifo[write_idx_q].V_dim                         <= instruction_i[11: 4];
    //             decoded_instruction_fifo[write_idx_q].U_dim                         <= instruction_i[19:12];
    //             decoded_instruction_fifo[write_idx_q].ITER_dim                      <= instruction_i[27:20];
    //             decoded_instruction_fifo[write_idx_q].unified_buffer_start_addr_rd  <= instruction_i[39:28];
    //             decoded_instruction_fifo[write_idx_q].unified_buffer_start_addr_wr  <= instruction_i[51:40];

    //             decoded_instruction_fifo[write_idx_q].V_dim1                        <= instruction_i[11: 4] - 1;
    //             decoded_instruction_fifo[write_idx_q].U_dim1                        <= instruction_i[19:12] - 1;
    //             decoded_instruction_fifo[write_idx_q].ITER_dim1                     <= instruction_i[27:20] - 1;
    //         end
    //         default: begin
    //         end
    //     endcase

    //     case(iq_state)
    //         RESET: begin
    //             iq_empty_o  <= '1;
    //             iq_full_o   <= '1;
    //             write_idx_q <= '0;
    //             read_idx_q  <= '0;
    //         end
    //         EMPTY: begin
    //             write_idx_q <= next_write_idx;
    //             //read_idx_q  <= next_read_idx;

    //             iq_empty_o  <= '1;
                
    //             if (write_i) begin
    //                 iq_empty_o  <= '0;
    //                 iq_state    <= STEADY;
    //             end
    //         end
    //         STEADY: begin
    //             write_idx_q <= next_write_idx;
    //             read_idx_q  <= next_read_idx;
        
    //             if ( write_i & next_write_idx == next_read_idx) begin
    //                 iq_full_o  <= '1;
    //                 iq_state   <= FULL;
    //             end

    //             if ( read_i & next_write_idx == next_read_idx) begin
    //                 iq_empty_o  <= '1;
    //                 iq_state   <= EMPTY;
    //             end
            
    //         end
    //         FULL: begin
    //             //write_idx_q <= next_write_idx;
    //             read_idx_q  <= next_read_idx;

    //             iq_full_o <= '1;
                
    //             if (read_i) begin
    //                 iq_full_o <= '0;
    //                 iq_state <= STEADY;
    //             end
    //         end
    //     endcase
        
    // end

endmodule

