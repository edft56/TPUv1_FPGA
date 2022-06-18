`timescale 1ns/1ns

package tpu_package;
    typedef enum logic {NORMAL, DIAG} acc_rd_mode;

    typedef logic [6:0] diag_addr_array_t [32];

    localparam W_WIDTH = 7;
    localparam ACT_WIDTH = 15;
    localparam RES_WIDTH = 31;
    localparam MUL_SIZE = 32;
    localparam INSTR_SIZE = 52;

    typedef logic [ 7:0] weight_t;
    typedef logic [ 8:0] weight_valid_t;
    typedef logic [15:0] act_t;
    typedef logic [31:0] res_t;
endpackage