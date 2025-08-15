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
    
    // Stage 1: Compute a*a and 0.3*b in parallel
    logic [FLEN-1:0] a_squared, mult_03b;
    logic a_squared_valid, mult_03b_valid;
    
    f_mult mult_a_squared (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(a),
        .up_valid(arg_vld),
        .res(a_squared),
        .down_valid(a_squared_valid),
        .busy(),
        .error()
    );
    
    f_mult mult_03b_stage (
        .clk(clk),
        .rst(rst),
        .a(CONST_03),
        .b(b),
        .up_valid(arg_vld),
        .res(mult_03b),
        .down_valid(mult_03b_valid),
        .busy(),
        .error()
    );
    
    // Delay registers for 'a' to use in subsequent multiplications
    logic [FLEN-1:0] a_r1, a_r2, a_r3;
    logic a_vld_r1, a_vld_r2, a_vld_r3;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            a_vld_r1 <= 1'b0;
            a_vld_r2 <= 1'b0;
            a_vld_r3 <= 1'b0;
        end else begin
            a_r1 <= a;
            a_r2 <= a_r1;
            a_r3 <= a_r2;
            a_vld_r1 <= arg_vld;
            a_vld_r2 <= a_vld_r1;
            a_vld_r3 <= a_vld_r2;
        end
    end
    
    // Stage 2: Compute a^3 = a^2 * a
    logic [FLEN-1:0] a_cubed;
    logic a_cubed_valid;
    
    f_mult mult_a_cubed (
        .clk(clk),
        .rst(rst),
        .a(a_squared),
        .b(a_r3),  // a delayed by 3 cycles to match a_squared timing
        .up_valid(a_squared_valid & a_vld_r3),
        .res(a_cubed),
        .down_valid(a_cubed_valid),
        .busy(),
        .error()
    );
    
    // More delay registers for 'a' for stages 3 and 4
    logic [FLEN-1:0] a_r4, a_r5, a_r6;
    logic a_vld_r4, a_vld_r5, a_vld_r6;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            a_vld_r4 <= 1'b0;
            a_vld_r5 <= 1'b0;
            a_vld_r6 <= 1'b0;
        end else begin
            a_r4 <= a_r3;
            a_r5 <= a_r4;
            a_r6 <= a_r5;
            a_vld_r4 <= a_vld_r3;
            a_vld_r5 <= a_vld_r4;
            a_vld_r6 <= a_vld_r5;
        end
    end
    
    // Stage 3: Compute a^4 = a^3 * a
    logic [FLEN-1:0] a_fourth;
    logic a_fourth_valid;
    
    f_mult mult_a_fourth (
        .clk(clk),
        .rst(rst),
        .a(a_cubed),
        .b(a_r6),  // a delayed by 6 cycles to match a_cubed timing
        .up_valid(a_cubed_valid & a_vld_r6),
        .res(a_fourth),
        .down_valid(a_fourth_valid),
        .busy(),
        .error()
    );
    
    // More delay registers for 'a' for stage 4
    logic [FLEN-1:0] a_r7, a_r8, a_r9;
    logic a_vld_r7, a_vld_r8, a_vld_r9;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            a_vld_r7 <= 1'b0;
            a_vld_r8 <= 1'b0;
            a_vld_r9 <= 1'b0;
        end else begin
            a_r7 <= a_r6;
            a_r8 <= a_r7;
            a_r9 <= a_r8;
            a_vld_r7 <= a_vld_r6;
            a_vld_r8 <= a_vld_r7;
            a_vld_r9 <= a_vld_r8;
        end
    end
    
    // Stage 4: Compute a^5 = a^4 * a
    logic [FLEN-1:0] a_fifth;
    logic a_fifth_valid;
    
    f_mult mult_a_fifth (
        .clk(clk),
        .rst(rst),
        .a(a_fourth),
        .b(a_r9),  // a delayed by 9 cycles to match a_fourth timing
        .up_valid(a_fourth_valid & a_vld_r9),
        .res(a_fifth),
        .down_valid(a_fifth_valid),
        .busy(),
        .error()
    );
    
    // Delay 0.3*b to align with a^5 timing 
    // 0.3*b is ready at cycle 3, a^5 is ready at cycle 12, so delay by 9 cycles
    logic [FLEN-1:0] mult_03b_r [0:8];
    logic mult_03b_vld_r [0:8];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 9; i++) begin
                mult_03b_vld_r[i] <= 1'b0;
            end
        end else begin
            mult_03b_r[0] <= mult_03b;
            mult_03b_vld_r[0] <= mult_03b_valid;
            for (int i = 1; i < 9; i++) begin
                mult_03b_r[i] <= mult_03b_r[i-1];
                mult_03b_vld_r[i] <= mult_03b_vld_r[i-1];
            end
        end
    end
    
    // Stage 5: Compute a^5 + 0.3*b
    logic [FLEN-1:0] sum_result;
    logic sum_valid;
    
    f_add add_a5_03b (
        .clk(clk),
        .rst(rst),
        .a(a_fifth),
        .b(mult_03b_r[8]),
        .up_valid(a_fifth_valid & mult_03b_vld_r[8]),
        .res(sum_result),
        .down_valid(sum_valid),
        .busy(),
        .error()
    );
    
    // Delay 'c' to align with sum timing
    // Sum is ready at cycle 16 (12 + 4), so delay c by 16 cycles
    logic [FLEN-1:0] c_r [0:15];
    logic c_vld_r [0:15];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 16; i++) begin
                c_vld_r[i] <= 1'b0;
            end
        end else begin
            c_r[0] <= c;
            c_vld_r[0] <= arg_vld;
            for (int i = 1; i < 16; i++) begin
                c_r[i] <= c_r[i-1];
                c_vld_r[i] <= c_vld_r[i-1];
            end
        end
    end
    
    // Stage 6: Compute result - c
    f_sub sub_final (
        .clk(clk),
        .rst(rst),
        .a(sum_result),
        .b(c_r[15]),
        .up_valid(sum_valid & c_vld_r[15]),
        .res(res),
        .down_valid(res_vld),
        .busy(),
        .error()
    );
    
    // Ready/valid handshake logic - accept inputs every cycle
    assign arg_rdy = 1'b1;

endmodule
