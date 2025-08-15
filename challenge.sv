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

    localparam [FLEN-1:0] CONST_0_3 = 64'h3FD3333333333333; // 0.3 in double precision

    // Pipeline with proper flow control for each operation
    // Each arithmetic operation takes 3-4 cycles, so total pipeline is around 20 cycles
    
    logic advance;
    assign advance = res_rdy | ~res_vld;
    assign arg_rdy = advance;
    
    // 20-stage pipeline
    logic [19:0] pipe_valid;
    logic [FLEN-1:0] a_pipe [0:19];
    logic [FLEN-1:0] b_pipe [0:19];
    logic [FLEN-1:0] c_pipe [0:19];
    
    // Pipeline control
    always_ff @(posedge clk) begin
        if (rst) begin
            pipe_valid <= 20'b0;
        end else if (advance) begin
            pipe_valid[19:1] <= pipe_valid[18:0];
            pipe_valid[0] <= arg_vld;
        end
    end
    
    // Data pipeline
    always_ff @(posedge clk) begin
        if (advance) begin
            a_pipe[0] <= a;
            b_pipe[0] <= b;
            c_pipe[0] <= c;
            
            for (int i = 1; i < 20; i++) begin
                a_pipe[i] <= a_pipe[i-1];
                b_pipe[i] <= b_pipe[i-1];
                c_pipe[i] <= c_pipe[i-1];
            end
        end
    end
    
    // Arithmetic units
    logic [FLEN-1:0] mult1_res, mult2_res, mult3_res, mult4_res, mult5_res;
    logic [FLEN-1:0] add_res, sub_res;
    logic mult1_down, mult2_down, mult3_down, mult4_down, mult5_down;
    logic add_down, sub_down;
    
    // Stage 0-2: a*a and 0.3*b in parallel
    f_mult mult1 (
        .clk(clk), .rst(rst),
        .a(a_pipe[0]), .b(a_pipe[0]),
        .up_valid(pipe_valid[0]),
        .res(mult1_res), .down_valid(mult1_down),
        .busy(), .error()
    );
    
    f_mult mult5 (
        .clk(clk), .rst(rst),
        .a(CONST_0_3), .b(b_pipe[0]),
        .up_valid(pipe_valid[0]),
        .res(mult5_res), .down_valid(mult5_down),
        .busy(), .error()
    );
    
    // Capture results from mult1 and mult5
    logic [FLEN-1:0] a_squared, b_scaled;
    always_ff @(posedge clk) begin
        if (advance) begin
            if (mult1_down) a_squared <= mult1_res;
            if (mult5_down) b_scaled <= mult5_res;
        end
    end
    
    // Stage 3-5: a^2 * a
    f_mult mult2 (
        .clk(clk), .rst(rst),
        .a(a_squared), .b(a_pipe[3]),
        .up_valid(pipe_valid[3] && mult1_down),
        .res(mult2_res), .down_valid(mult2_down),
        .busy(), .error()
    );
    
    logic [FLEN-1:0] a_cubed;
    always_ff @(posedge clk) begin
        if (advance && mult2_down) a_cubed <= mult2_res;
    end
    
    // Stage 6-8: a^3 * a
    f_mult mult3 (
        .clk(clk), .rst(rst),
        .a(a_cubed), .b(a_pipe[6]),
        .up_valid(pipe_valid[6] && mult2_down),
        .res(mult3_res), .down_valid(mult3_down),
        .busy(), .error()
    );
    
    logic [FLEN-1:0] a_fourth;
    always_ff @(posedge clk) begin
        if (advance && mult3_down) a_fourth <= mult3_res;
    end
    
    // Stage 9-11: a^4 * a
    f_mult mult4 (
        .clk(clk), .rst(rst),
        .a(a_fourth), .b(a_pipe[9]),
        .up_valid(pipe_valid[9] && mult3_down),
        .res(mult4_res), .down_valid(mult4_down),
        .busy(), .error()
    );
    
    logic [FLEN-1:0] a_fifth;
    always_ff @(posedge clk) begin
        if (advance && mult4_down) a_fifth <= mult4_res;
    end
    
    // Stage 12-15: a^5 + 0.3*b (f_add takes 4 cycles)
    f_add adder (
        .clk(clk), .rst(rst),
        .a(a_fifth), .b(b_scaled),
        .up_valid(pipe_valid[12] && mult4_down && mult5_down),
        .res(add_res), .down_valid(add_down),
        .busy(), .error()
    );
    
    logic [FLEN-1:0] sum_result;
    always_ff @(posedge clk) begin
        if (advance && add_down) sum_result <= add_res;
    end
    
    // Stage 16-18: (a^5 + 0.3*b) - c
    f_sub subtractor (
        .clk(clk), .rst(rst),
        .a(sum_result), .b(c_pipe[16]),
        .up_valid(pipe_valid[16] && add_down),
        .res(sub_res), .down_valid(sub_down),
        .busy(), .error()
    );
    
    // Output
    always_ff @(posedge clk) begin
        if (rst) begin
            res_vld <= 1'b0;
        end else if (advance) begin
            res_vld <= pipe_valid[19] && sub_down;
            if (sub_down) begin
                res <= sub_res;
            end
        end
    end

endmodule
