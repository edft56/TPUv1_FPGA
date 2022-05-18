module systolic_data_staging(   input clk_i,
                                input logic [15:0] data_in [32],
                                
                                output logic [15:0] data_out [32]
                                );
    
    logic [15:0] register_array [32][32]; //half of them are used

    always_ff @(posedge clk_i) begin
        for(int i=0; i<32; i++) begin
            register_array[i][i] <= data_in[i];
        end

        for(int i=0; i<32; i++) begin
            for(int j=i; j<32; j++) begin
                register_array[i][j] <= register_array[i+1][j];
            end
        end
        
        for(int i=0; i<32; i++) begin
            data_out[i] <= register_array[0][i];
        end
    end

endmodule
