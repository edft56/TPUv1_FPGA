`timescale 1ns/1ns

module systolic_data_staging(   input clk_i,
                                input read_i,
                                input logic [15:0] data_i [32],
                                
                                output act_data_rdy_o,
                                output logic [15:0] data_o [32]
                                );
    
    logic [15:0] register_array [31][31]; //half of them are used
    logic write_en_q;

    initial begin
        for(int i=0; i<31; i++) begin
            register_array[i] = '{default:0};
        end

    end

    always_comb begin
        for(int i=0; i<31; i++) begin
            data_o[i+1] = register_array[0][i];
        end
        data_o[0] = data_i[0];
    end

    always_ff @(posedge clk_i) begin
        write_en_q <= read_i;

        for(int i=0; i<31; i++) begin
            register_array[i][i] <= (read_i) ? data_i[i+1] :  'd0;
        end
        

        for(int i=0; i<30; i++) begin
            for(int j=i; j<31; j++) begin
                if(i!=j) begin
                    register_array[i][j] <= register_array[i+1][j]; //shift
                end
            end
        end
        
    end

endmodule
