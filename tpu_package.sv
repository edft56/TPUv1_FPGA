`timescale 1ns/1ns

package tpu_package;
    typedef enum logic {NORMAL, DIAG} acc_rd_mode;

    typedef logic [6:0] diag_addr_array_t [32];

    localparam W_WIDTH = 7;
    localparam ACT_WIDTH = 15;
    localparam RES_WIDTH = 31;
    localparam MUL_SIZE = 32;

    typedef logic [ 7:0] weight_t;
    typedef logic [ 8:0] weight_valid_t;
    typedef logic [15:0] act_t;
    typedef logic [31:0] res_t;

    function diag_addr_array_t diag_addr_LUT (input logic [6:0] addr);
        diag_addr_array_t out_addr;
        //something something will write when bored
        //hope verilog will some day have compile time lut creation
        return out_addr;
    endfunction
endpackage