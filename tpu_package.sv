`timescale 1ns/1ns

package tpu_package;
    typedef enum logic {NORMAL, DIAG} acc_rd_mode;

    typedef logic [6:0] diag_addr_array_t [32];

    localparam W_WIDTH = 7;
    localparam ACT_WIDTH = 15;
    localparam RES_WIDTH = 31;
    localparam MUL_SIZE = 32;
    localparam INSTR_SIZE = 52;

    typedef struct packed{
        logic [2:0] MAC_op;
        logic [7:0] V_dim;
        logic [7:0] U_dim;
        logic [7:0] ITER_dim;
        logic [6:0] V_dim1;
        logic [6:0] U_dim1;
        logic [6:0] ITER_dim1;
        logic [11:0] unified_buffer_start_addr_rd;
        logic [11:0] unified_buffer_start_addr_wr;
    } decoded_instr_t; //72 bits

    typedef logic [ 7:0] weight_t;
    typedef logic [ 8:0] weight_valid_t;
    typedef logic [15:0] act_t;
    typedef logic [31:0] res_t;
endpackage