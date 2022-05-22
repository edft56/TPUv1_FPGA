`timescale 1ns/1ns

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