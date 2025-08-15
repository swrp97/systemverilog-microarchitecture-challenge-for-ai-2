/*

Put any submodules you need here.

You are not allowed to implement your own submodules or functions for the addition,
subtraction, multiplication, division, comparison or getting the square
root of floating-point numbers. For such operations you can only use the
modules from the arithmetic_block_wrappers directory.

*/

module challenge
(
    input                     clk,
    input                     rst,

    input                     arg_vld,
    output                    arg_rdy,
    input        [FLEN - 1:0] a,
    input        [FLEN - 1:0] b,
    input        [FLEN - 1:0] c,

    output logic              res_vld,
    input  logic              res_rdy,
    output logic [FLEN - 1:0] res
);
    // Formula: a ** 5 + 0.3 * b - c
    // IEEE 754 double precision constant for 0.3
    localparam [FLEN-1:0] CONST_03 = 64'h3FD3333333333333;
    
    // Test step by step - let's just try 0.3 * b
    f_mult mult_03b_test (
        .clk(clk),
        .rst(rst),
        .a(CONST_03),
        .b(b),
        .up_valid(arg_vld),
        .res(res),
        .down_valid(res_vld),
        .busy(),
        .error()
    );
    
    // Ready/valid handshake logic
    assign arg_rdy = 1'b1;

endmodule
