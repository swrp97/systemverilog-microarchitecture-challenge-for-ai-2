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
    
    // For now, accept inputs every cycle - will optimize backpressure later
    assign arg_rdy = 1'b1;
    
    // Step 1: Compute a^2 and 0.3*b in parallel
    logic [FLEN-1:0] a_sq, mult_03b;
    logic a_sq_vld, mult_03b_vld;
    
    f_mult mult1 (
        .clk(clk), .rst(rst),
        .a(a), .b(a),
        .up_valid(arg_vld),
        .res(a_sq), .down_valid(a_sq_vld),
        .busy(), .error()
    );
    
    f_mult mult2 (
        .clk(clk), .rst(rst),
        .a(CONST_03), .b(b),
        .up_valid(arg_vld),
        .res(mult_03b), .down_valid(mult_03b_vld),
        .busy(), .error()
    );
    
    // Delay line for 'a' values
    logic [FLEN-1:0] a_d1, a_d2, a_d3, a_d4, a_d5, a_d6, a_d7, a_d8, a_d9;
    logic a_vld_d1, a_vld_d2, a_vld_d3, a_vld_d4, a_vld_d5, a_vld_d6, a_vld_d7, a_vld_d8, a_vld_d9;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            a_vld_d1 <= 0; a_vld_d2 <= 0; a_vld_d3 <= 0; a_vld_d4 <= 0; a_vld_d5 <= 0;
            a_vld_d6 <= 0; a_vld_d7 <= 0; a_vld_d8 <= 0; a_vld_d9 <= 0;
        end else begin
            a_d1 <= a; a_vld_d1 <= arg_vld;
            a_d2 <= a_d1; a_vld_d2 <= a_vld_d1;
            a_d3 <= a_d2; a_vld_d3 <= a_vld_d2;
            a_d4 <= a_d3; a_vld_d4 <= a_vld_d3;
            a_d5 <= a_d4; a_vld_d5 <= a_vld_d4;
            a_d6 <= a_d5; a_vld_d6 <= a_vld_d5;
            a_d7 <= a_d6; a_vld_d7 <= a_vld_d6;
            a_d8 <= a_d7; a_vld_d8 <= a_vld_d7;
            a_d9 <= a_d8; a_vld_d9 <= a_vld_d8;
        end
    end
    
    // Step 2: Compute a^3 = a^2 * a (need a delayed by 3 cycles)
    logic [FLEN-1:0] a_cubed;
    logic a_cubed_vld;
    
    f_mult mult3 (
        .clk(clk), .rst(rst),
        .a(a_sq), .b(a_d3),
        .up_valid(a_sq_vld & a_vld_d3),
        .res(a_cubed), .down_valid(a_cubed_vld),
        .busy(), .error()
    );
    
    // Step 3: Compute a^4 = a^3 * a (need a delayed by 6 cycles)
    logic [FLEN-1:0] a_fourth;
    logic a_fourth_vld;
    
    f_mult mult4 (
        .clk(clk), .rst(rst),
        .a(a_cubed), .b(a_d6),
        .up_valid(a_cubed_vld & a_vld_d6),
        .res(a_fourth), .down_valid(a_fourth_vld),
        .busy(), .error()
    );
    
    // Step 4: Compute a^5 = a^4 * a (need a delayed by 9 cycles)
    logic [FLEN-1:0] a_fifth;
    logic a_fifth_vld;
    
    f_mult mult5 (
        .clk(clk), .rst(rst),
        .a(a_fourth), .b(a_d9),
        .up_valid(a_fourth_vld & a_vld_d9),
        .res(a_fifth), .down_valid(a_fifth_vld),
        .busy(), .error()
    );
    
    // Delay line for 0.3*b to align with a^5 (delay by 9 cycles)
    logic [FLEN-1:0] mult_03b_d1, mult_03b_d2, mult_03b_d3, mult_03b_d4, mult_03b_d5;
    logic [FLEN-1:0] mult_03b_d6, mult_03b_d7, mult_03b_d8, mult_03b_d9;
    logic mult_03b_vld_d1, mult_03b_vld_d2, mult_03b_vld_d3, mult_03b_vld_d4, mult_03b_vld_d5;
    logic mult_03b_vld_d6, mult_03b_vld_d7, mult_03b_vld_d8, mult_03b_vld_d9;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            mult_03b_vld_d1 <= 0; mult_03b_vld_d2 <= 0; mult_03b_vld_d3 <= 0; mult_03b_vld_d4 <= 0; mult_03b_vld_d5 <= 0;
            mult_03b_vld_d6 <= 0; mult_03b_vld_d7 <= 0; mult_03b_vld_d8 <= 0; mult_03b_vld_d9 <= 0;
        end else begin
            mult_03b_d1 <= mult_03b; mult_03b_vld_d1 <= mult_03b_vld;
            mult_03b_d2 <= mult_03b_d1; mult_03b_vld_d2 <= mult_03b_vld_d1;
            mult_03b_d3 <= mult_03b_d2; mult_03b_vld_d3 <= mult_03b_vld_d2;
            mult_03b_d4 <= mult_03b_d3; mult_03b_vld_d4 <= mult_03b_vld_d3;
            mult_03b_d5 <= mult_03b_d4; mult_03b_vld_d5 <= mult_03b_vld_d4;
            mult_03b_d6 <= mult_03b_d5; mult_03b_vld_d6 <= mult_03b_vld_d5;
            mult_03b_d7 <= mult_03b_d6; mult_03b_vld_d7 <= mult_03b_vld_d6;
            mult_03b_d8 <= mult_03b_d7; mult_03b_vld_d8 <= mult_03b_vld_d7;
            mult_03b_d9 <= mult_03b_d8; mult_03b_vld_d9 <= mult_03b_vld_d8;
        end
    end
    
    // Step 5: Compute a^5 + 0.3*b
    logic [FLEN-1:0] sum_result;
    logic sum_vld;
    
    f_add add1 (
        .clk(clk), .rst(rst),
        .a(a_fifth), .b(mult_03b_d9),
        .up_valid(a_fifth_vld & mult_03b_vld_d9),
        .res(sum_result), .down_valid(sum_vld),
        .busy(), .error()
    );
    
    // Delay line for 'c' to align with sum result (delay by 16 cycles total)
    logic [FLEN-1:0] c_d [0:16];
    logic c_vld_d [0:16];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i <= 16; i++) c_vld_d[i] <= 0;
        end else begin
            c_d[0] <= c; c_vld_d[0] <= arg_vld;
            for (int i = 1; i <= 16; i++) begin
                c_d[i] <= c_d[i-1];
                c_vld_d[i] <= c_vld_d[i-1];
            end
        end
    end
    
    // Step 6: Compute final result - c
    f_sub sub1 (
        .clk(clk), .rst(rst),
        .a(sum_result), .b(c_d[16]),
        .up_valid(sum_vld & c_vld_d[16]),
        .res(res), .down_valid(res_vld),
        .busy(), .error()
    );

endmodule
