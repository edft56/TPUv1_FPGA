`timescale 1ns/1ns

`ifndef TPU_PACK  // guard
    `define TPU_PACK
    `include "tpu_package.sv"
`endif   // guard

module MAC_unit_compute
                        import tpu_package::*;    
                        (input               clk_i,rst_i,
                        input  logic [W_WIDTH:0] weight_i,
                        input  logic [ACT_WIDTH:0] act_i,
                        input  logic [RES_WIDTH:0] add_i,

                        output logic [RES_WIDTH:0] out_q
                        );

    always_ff @( posedge clk_i ) begin
        if (rst_i) begin
            out_q       <= '0;
        end
        else begin
            out_q       <= (RES_WIDTH+1)'( (RES_WIDTH+1)'(act_i * weight_i) + (RES_WIDTH+1)'(add_i) ); //size casting unsigned so should add 0s
        end
    end

endmodule

module MAC_unit_shell
                        import tpu_package::*;    
                        (  input               clk_i, rst_i,
                        input               stall_i, load_weights_i, compute_i, load_activations_i,
                        input  compute_weight_sel_i,      
                        input  logic [W_WIDTH:0] mem_weight_i,
                        input  logic [ACT_WIDTH:0] act_i,
                        input  logic [RES_WIDTH:0] add_i,

                        output logic [RES_WIDTH:0] out_o,
                        output logic [ACT_WIDTH:0] act_o,
                        output logic [W_WIDTH:0] weight_o
                        );

    logic [W_WIDTH:0] weight_q [2];
    logic [ACT_WIDTH:0] act_q;


    MAC_unit_compute MAC0(  .clk_i,
                            .rst_i,
                            .weight_i( (compute_weight_sel_i) ? weight_q[1] : weight_q[0]),
                            .act_i,
                            .add_i,
                            
                            .out_q(out_o)
                        );

    assign act_o    = act_q;
    assign weight_o = weight_q[~compute_weight_sel_i];

    always_ff @(posedge clk_i) begin

        if(stall_i) begin
            act_q    <= act_q;
            weight_q <= weight_q;
        end
        else begin
            if(load_weights_i) begin
                weight_q[~compute_weight_sel_i] <= mem_weight_i;
            end
            if(load_activations_i | compute_i) begin
                act_q                           <= act_i;
            end
        end


    end

endmodule


module MAC_systolic_array
                        import tpu_package::*;    
                        (  input clk_i,rst_i,
                            input [MUL_SIZE-1 : 0] load_weights_i,
                            input stall_i, compute_i, load_activations_i,
                            input next_weight_tile_i,
                            input logic [   W_WIDTH:0] mem_weight_i [MUL_SIZE],
                            input logic [ ACT_WIDTH:0] mem_act_i    [MUL_SIZE],
                            input compute_weights_buffered_i,
                            input compute_weights_rdy_i,
                            input logic [MUL_SIZE-1 : 0] compute_weight_sel_i [MUL_SIZE],

                            output logic [RES_WIDTH:0] data_o       [MUL_SIZE]
                            );

    logic [  W_WIDTH : 0] weight_connections [MUL_SIZE+1][MUL_SIZE];
    logic [ACT_WIDTH : 0] act_connections    [MUL_SIZE+1][MUL_SIZE];
    logic [RES_WIDTH : 0] out_connections    [MUL_SIZE+1][MUL_SIZE];
    logic read_en_lag;

    logic first_pass_q;
    logic next_weight_tile_flag_q;

    initial next_weight_tile_flag_q = 0;
    initial first_pass_q = 0;

    always_comb begin
        weight_connections[0] = mem_weight_i;
        act_connections[0] = mem_act_i;


        for(int i=1; i<MUL_SIZE+1; i++) begin
            data_o [i-1] = out_connections[i][MUL_SIZE-1];
        end

    end

    always_ff @(posedge clk_i) begin
        //read_en_lag <= load_weights_i;

        //first_pass_q <= (compute_weights_rdy_i) ? '1 : first_pass_q;

        // compute_weight_sel_q <= (compute_weights_rdy_i & !first_pass_q) ? ~compute_weight_sel_q : compute_weight_sel_q;

        // if (next_weight_tile_i) begin
        //     if (compute_weights_buffered_i) begin
        //         compute_weight_sel_q <= ~compute_weight_sel_q;
        //     end
        //     else begin
        //         next_weight_tile_flag_q <= '1;
        //     end
        // end

        // if(next_weight_tile_flag_q) begin
        //     if(compute_weights_rdy_i) begin
        //         compute_weight_sel_q <= ~compute_weight_sel_q;
        //         next_weight_tile_flag_q <= '0;
        //     end
        // end
    end

    

    generate 

        for(genvar i=1; i<MUL_SIZE+1; i++) begin: MAC_ROW
            for(genvar j=0; j<MUL_SIZE; j++) begin: MAC_COL

                MAC_unit_shell MAC_array_mid(   .clk_i,
                                                .rst_i,
                                                .stall_i,
                                                .load_weights_i(load_weights_i[MUL_SIZE-i]),
                                                .compute_i,   
                                                .load_activations_i,
                                                .compute_weight_sel_i(compute_weight_sel_i[i-1][MUL_SIZE-1-j]),
                                                .mem_weight_i(weight_connections[i-1][j]),   
                                                .act_i(act_connections[i-1][j]),
                                                .add_i((j-1>=0) ? out_connections[i][j-1] : 0),

                                                .out_o(out_connections[i][j]),
                                                .act_o(act_connections[i][j]),
                                                .weight_o(weight_connections[i][j])
                                            );

            end: MAC_COL
        end: MAC_ROW
    endgenerate


endmodule

