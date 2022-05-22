`timescale 1ns/1ns

module systolic_data_staging(   input clk_i,
                                input read_i,
                                input logic [15:0] data_i [32],
                                
                                output act_data_rdy_o,
                                output logic [15:0] data_o [32]
                                );
    
    logic [15:0] register_array [32][32]; //half of them are used
    //logic        valid_bit;

    initial begin
        for(int i=0; i<32; i++) begin
            register_array[i] = '{default:0};
        end

        //valid_bit = 1'b0;
    end

    always_ff @(posedge clk_i) begin
        
        for(int i=0; i<32; i++) begin
            register_array[i][i] <= (read_i) ? data_i[i] :  'd0;
            //valid_bits[i][i]     <= (read_i) ? 1'b1       : 1'b0;
        end
        //valid_bit <= (read_i) ? 1'b1 :  1'b0;
        act_data_rdy_o <= (read_i) ? 1'b1 : 1'b0;
        

        for(int i=0; i<32; i++) begin
            for(int j=i; j<32; j++) begin
                register_array[i][j] <= register_array[i+1][j];
            end
        end
        
        for(int i=0; i<32; i++) begin
            data_o[i] <= register_array[0][i];
        end
    end

endmodule
