package Acc_types;
    typedef enum logic {NORMAL, DIAG} acc_rd_mode;

    typedef logic [6:0] diag_addr_array_t [32];

    function diag_addr_array_t diag_addr_LUT (input logic [6:0] addr);
        diag_addr_array_t out_addr;
        //something something will write when bored
        //hope verilog will some day have compile time lut creation
        return out_addr;
    endfunction
endpackage

module Accumulator( input   clk_i, rst_i,
                    input   port1_rd_en_i,
                    input   port2_wr_en_i,
                    input   Acc_types::acc_rd_mode accumulator_read_mode,
                    input   logic [31:0] data_i [32],
                    input   logic [6:0] addr_wr,
                    input   logic [6:0] addr_rd,

                    output  logic [31:0] data_o [32]
                    );
    import Acc_types::*;

    logic [31:0] accumulator_storage [128][32];
    diag_addr_array_t diag_addr;

    always_ff @(posedge clk_i, posedge rst_i) begin
        if(port2_wr_en_i) begin
            accumulator_storage[addr_wr][31:0]  <= data_i;
        end
        
        if(port1_rd_en_i) begin
            if(accumulator_read_mode == NORMAL) data_o <= accumulator_storage[addr_rd][31:0];
            else begin
                diag_addr <= diag_addr_LUT(addr_rd);
                for(int i=0; i<32; i++) data_o[i] <= accumulator_storage[diag_addr[i]][i];
            end
            
        end
    end

endmodule
