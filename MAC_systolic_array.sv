`timescale 1ns/1ns


module MAC_unit_compute(input               clk_i,rst_i,
                        input  logic [ 7:0] weight_i,
                        input  logic [15:0] act_i,
                        input  logic [31:0] add_i,

                        output logic [31:0] out_q
                        );

    always_ff @( posedge clk_i ) begin
        if (rst_i) begin
            out_q       <= '0;
        end
        else begin
            out_q       <= 32'( 32'(act_i * weight_i) + 32'(add_i) ); //size casting unsigned so should add 0s
        end
    end

endmodule

module MAC_unit_shell(  input               clk_i, rst_i,
                        input               stall_i, load_weights_i, compute_i,        
                        input  logic [ 7:0] mem_weight_i,
                        input  logic [15:0] act_i,
                        input  logic [31:0] add_i,

                        output logic [31:0] out_o,
                        output logic [15:0] act_o,
                        output logic [ 7:0] weight_o
                        );

    logic [ 7:0] weight_q;
    logic [15:0] act_q;


    MAC_unit_compute MAC0(  .clk_i,
                            .rst_i,
                            .weight_i(weight_q),
                            .act_i,
                            .add_i,
                            
                            .out_q(out_o)
                        );

    assign act_o    = act_q;
    assign weight_o = weight_q;

    always_ff @(posedge clk_i) begin

        if(stall_i) begin
            act_q    <= act_q;
            weight_q <= weight_q;
        end
        else begin
            if(load_weights_i) begin
                act_q    <= act_q;
                weight_q <= mem_weight_i;
            end
            else if(compute_i) begin
                act_q    <= act_i;
                weight_q <= weight_q;
            end
        end


    end

endmodule


module MAC_systolic_array(  input clk_i,rst_i,
                            input stall_i, load_weights_i, compute_i,
                            input logic [ 7:0] mem_weight_i [32],
                            input logic [15:0] mem_act_i [32],
                            //input logic [31:0] mem_add_i [32],

                            output logic [31:0] data_o [32]
                            );

    logic [ 7:0] weight_connections [34][32];
    logic [15:0] act_connections [34][32];
    logic [31:0] out_connections [34][32];
    logic read_en_lag;

    // always_comb begin
    //     for(int i=0; i<32; i++) begin
    //         data_o [i] = out_connections[i][31];
    //     end

    // end

    // generate 
    //     MAC_unit_shell MAC_array_row1_col1(  .clk_i,
    //                                         .rst_i,
    //                                         .stall_i,
    //                                         .load_weights_i,
    //                                         .compute_i,             
    //                                         .mem_weight_i(mem_weight_i[0]),
    //                                         .act_i(mem_act_i[0]),
    //                                         .add_i(/*mem_add_i[0]*/), //maybe can be used to add bias

    //                                         .out_o(out_connections[0][0]),
    //                                         .act_o(act_connections[0][0]),
    //                                         .weight_o(weight_connections[0][0])
    //                                         );

    //     for(genvar j=1; j<32; j++) begin : MAC_ROW1
    //         MAC_unit_shell MAC_array_row1(  .clk_i,
    //                                         .rst_i,
    //                                         .stall_i,
    //                                         .load_weights_i,
    //                                         .compute_i,             
    //                                         .mem_weight_i(mem_weight_i[j]),
    //                                         .act_i(mem_act_i[j]),
    //                                         .add_i(out_connections[0][j-1]),

    //                                         .out_o(out_connections[0][j]),
    //                                         .act_o(act_connections[0][j]),
    //                                         .weight_o(weight_connections[0][j])
    //                                         );
    //     end : MAC_ROW1

    //     for(genvar i=1; i<32; i++) begin : MAC_COL1
    //         MAC_unit_shell MAC_array_col1(  .clk_i,
    //                                         .rst_i,
    //                                         .stall_i,
    //                                         .load_weights_i,
    //                                         .compute_i,             
    //                                         .mem_weight_i(weight_connections[i-1][0]),
    //                                         .act_i(act_connections[i-1][0]),
    //                                         .add_i(/*mem_add_i[j]*/), //maybe can be used to add bias

    //                                         .out_o(out_connections[i][0]),
    //                                         .act_o(act_connections[i][0]),
    //                                         .weight_o(weight_connections[i][0])
    //                                         );
    //     end : MAC_COL1

    //     for(genvar i=1; i<32; i++) begin: MAC_ROW
    //         for(genvar j=1; j<32; j++) begin: MAC_COL

    //             MAC_unit_shell MAC_array_mid(   .clk_i,
    //                                             .rst_i,
    //                                             .stall_i,
    //                                             .load_weights_i,
    //                                             .compute_i,   
    //                                             .mem_weight_i(weight_connections[i-1][j]),   
    //                                             .act_i(act_connections[i-1][j]),
    //                                             .add_i(out_connections[i][j-1]),

    //                                             .out_o(out_connections[i][j]),
    //                                             .act_o(act_connections[i][j]),
    //                                             .weight_o(weight_connections[i][j])
    //                                         );

    //         end: MAC_COL
    //     end: MAC_ROW
    // endgenerate

    always_comb begin
        weight_connections[33] = mem_weight_i;
        act_connections[0] = mem_act_i;


        for(int i=1; i<33; i++) begin
            data_o [i-1] = out_connections[i][31];
        end

    end

    always_ff @(posedge clk_i) begin
        read_en_lag <= load_weights_i;
    end

    

    generate 

        for(genvar i=1; i<33; i++) begin: MAC_ROW
            for(genvar j=0; j<32; j++) begin: MAC_COL

                MAC_unit_shell MAC_array_mid(   .clk_i,
                                                .rst_i,
                                                .stall_i,
                                                .load_weights_i(read_en_lag),
                                                .compute_i,   
                                                .mem_weight_i(weight_connections[i+1][j]),   
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

