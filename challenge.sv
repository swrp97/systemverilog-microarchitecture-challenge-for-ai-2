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
    /*

    The Prompt:

    Finish the code of a pipelined block in the file challenge.sv. The block
    computes a formula "a ** 5 + 0.3 * b - c". Ready/valid handshakes for
    the arguments and the result follow the same rules as ready/valid in AXI
    Stream. When a block is not busy, arg_rdy should be 1, it should not
    wait for arg_vld. You are not allowed to implement your own submodules
    or functions for the addition, subtraction, multiplication, division,
    comparison or getting the square root of floating-point numbers. For
    such operations you can only use the modules from the
    arithmetic_block_wrappers directory. You are not allowed to change any
    other files except challenge.sv. You can check the results by running
    the script "simulate". If the script outputs "FAIL" or does not output
    "PASS" from the code in the provided testbench.sv by running the
    provided script "simulate", your design is not working and is not an
    answer to the challenge. Your design must be able to accept a new set of
    the inputs (a, b and c) each clock cycle back-to-back and generate the
    computation results without any stalls and without requiring empty cycle
    gaps in the input. The solution code has to be synthesizable
    SystemVerilog RTL. A human should not help AI by tipping anything on
    latencies or handshakes of the submodules. The AI has to figure this out
    by itself by analyzing the code in the repository directories. Likewise
    a human should not instruct AI how to build a pipeline structure since
    it makes the exercise meaningless.

    */

    // Constants
    localparam [FLEN-1:0] CONST_0_3 = 64'h3FD3333333333333; // 0.3 in double precision

    // Pipeline enable - can advance when output is ready or no output yet
    logic pipe_enable;
    assign pipe_enable = res_rdy | ~res_vld;
    assign arg_rdy = pipe_enable;

    // Main pipeline - 18 stages to handle full computation latency
    logic [17:0] stage_valid;
    logic [FLEN-1:0] a_pipe [0:17];
    logic [FLEN-1:0] b_pipe [0:17]; 
    logic [FLEN-1:0] c_pipe [0:17];

    // Pipeline advancement
    always_ff @(posedge clk) begin
        if (rst) begin
            stage_valid <= 18'b0;
        end else if (pipe_enable) begin
            stage_valid[17:1] <= stage_valid[16:0];
            stage_valid[0] <= arg_vld;
        end
    end

    // Data pipeline registers
    always_ff @(posedge clk) begin
        if (pipe_enable) begin
            a_pipe[0] <= a;
            b_pipe[0] <= b;
            c_pipe[0] <= c;
            
            for (int i = 1; i < 18; i++) begin
                a_pipe[i] <= a_pipe[i-1];
                b_pipe[i] <= b_pipe[i-1];
                c_pipe[i] <= c_pipe[i-1];
            end
        end
    end

    // Arithmetic operations
    // Note: Each f_mult/f_add/f_sub takes 3 cycles from up_valid to down_valid

    // Stage 0-2: Compute a*a (a^2) and 0.3*b in parallel
    logic [FLEN-1:0] a2_result, b_scaled_result;
    logic a2_down_valid, b_scaled_down_valid;

    f_mult mult_a2 (
        .clk(clk), .rst(rst),
        .a(a_pipe[0]), .b(a_pipe[0]),
        .up_valid(stage_valid[0]),
        .res(a2_result), .down_valid(a2_down_valid),
        .busy(), .error()
    );

    f_mult mult_scale (
        .clk(clk), .rst(rst),
        .a(CONST_0_3), .b(b_pipe[0]),
        .up_valid(stage_valid[0]),
        .res(b_scaled_result), .down_valid(b_scaled_down_valid),
        .busy(), .error()
    );

    // Pipeline registers to store a^2 and b_scaled results
    logic [FLEN-1:0] a2_pipe [0:15];  // Need to pipeline a^2 forward
    logic [FLEN-1:0] b_scaled_pipe [0:15];  // Need to pipeline b_scaled forward
    logic [14:0] a2_valid_pipe, b_scaled_valid_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            a2_valid_pipe <= 15'b0;
            b_scaled_valid_pipe <= 15'b0;
        end else if (pipe_enable) begin
            a2_valid_pipe[14:1] <= a2_valid_pipe[13:0];
            a2_valid_pipe[0] <= a2_down_valid;
            
            b_scaled_valid_pipe[14:1] <= b_scaled_valid_pipe[13:0];
            b_scaled_valid_pipe[0] <= b_scaled_down_valid;
            
            if (a2_down_valid) a2_pipe[0] <= a2_result;
            if (b_scaled_down_valid) b_scaled_pipe[0] <= b_scaled_result;
            
            for (int i = 1; i < 15; i++) begin
                a2_pipe[i] <= a2_pipe[i-1];
                b_scaled_pipe[i] <= b_scaled_pipe[i-1];
            end
        end
    end

    // Stage 3-5: Compute a^2 * a = a^3
    logic [FLEN-1:0] a3_result;
    logic a3_down_valid;

    f_mult mult_a3 (
        .clk(clk), .rst(rst),
        .a(a2_pipe[0]), .b(a_pipe[3]),
        .up_valid(a2_valid_pipe[0] && stage_valid[3]),
        .res(a3_result), .down_valid(a3_down_valid),
        .busy(), .error()
    );

    // Pipeline registers for a^3
    logic [FLEN-1:0] a3_pipe [0:11];
    logic [11:0] a3_valid_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            a3_valid_pipe <= 12'b0;
        end else if (pipe_enable) begin
            a3_valid_pipe[11:1] <= a3_valid_pipe[10:0];
            a3_valid_pipe[0] <= a3_down_valid;
            
            if (a3_down_valid) a3_pipe[0] <= a3_result;
            
            for (int i = 1; i < 12; i++) begin
                a3_pipe[i] <= a3_pipe[i-1];
            end
        end
    end

    // Stage 6-8: Compute a^3 * a = a^4  
    logic [FLEN-1:0] a4_result;
    logic a4_down_valid;

    f_mult mult_a4 (
        .clk(clk), .rst(rst),
        .a(a3_pipe[0]), .b(a_pipe[6]),
        .up_valid(a3_valid_pipe[0] && stage_valid[6]),
        .res(a4_result), .down_valid(a4_down_valid),
        .busy(), .error()
    );

    // Pipeline registers for a^4
    logic [FLEN-1:0] a4_pipe [0:8];
    logic [8:0] a4_valid_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            a4_valid_pipe <= 9'b0;
        end else if (pipe_enable) begin
            a4_valid_pipe[8:1] <= a4_valid_pipe[7:0];
            a4_valid_pipe[0] <= a4_down_valid;
            
            if (a4_down_valid) a4_pipe[0] <= a4_result;
            
            for (int i = 1; i < 9; i++) begin
                a4_pipe[i] <= a4_pipe[i-1];
            end
        end
    end

    // Stage 9-11: Compute a^4 * a = a^5
    logic [FLEN-1:0] a5_result;
    logic a5_down_valid;

    f_mult mult_a5 (
        .clk(clk), .rst(rst),
        .a(a4_pipe[0]), .b(a_pipe[9]),
        .up_valid(a4_valid_pipe[0] && stage_valid[9]),
        .res(a5_result), .down_valid(a5_down_valid),
        .busy(), .error()
    );

    // Pipeline registers for a^5
    logic [FLEN-1:0] a5_pipe [0:5];
    logic [5:0] a5_valid_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            a5_valid_pipe <= 6'b0;
        end else if (pipe_enable) begin
            a5_valid_pipe[5:1] <= a5_valid_pipe[4:0];
            a5_valid_pipe[0] <= a5_down_valid;
            
            if (a5_down_valid) a5_pipe[0] <= a5_result;
            
            for (int i = 1; i < 6; i++) begin
                a5_pipe[i] <= a5_pipe[i-1];
            end
        end
    end

    // Stage 12-14: Compute a^5 + 0.3*b
    logic [FLEN-1:0] sum_result;
    logic sum_down_valid;

    f_add adder (
        .clk(clk), .rst(rst),
        .a(a5_pipe[0]), .b(b_scaled_pipe[9]),  // b_scaled from 9 stages earlier
        .up_valid(a5_valid_pipe[0] && b_scaled_valid_pipe[9] && stage_valid[12]),
        .res(sum_result), .down_valid(sum_down_valid),
        .busy(), .error()
    );

    // Pipeline registers for sum
    logic [FLEN-1:0] sum_pipe [0:2];
    logic [2:0] sum_valid_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            sum_valid_pipe <= 3'b0;
        end else if (pipe_enable) begin
            sum_valid_pipe[2:1] <= sum_valid_pipe[1:0];
            sum_valid_pipe[0] <= sum_down_valid;
            
            if (sum_down_valid) sum_pipe[0] <= sum_result;
            
            for (int i = 1; i < 3; i++) begin
                sum_pipe[i] <= sum_pipe[i-1];
            end
        end
    end

    // Stage 15-17: Compute (a^5 + 0.3*b) - c
    logic [FLEN-1:0] final_result;
    logic final_down_valid;

    f_sub subtractor (
        .clk(clk), .rst(rst),
        .a(sum_pipe[0]), .b(c_pipe[15]),
        .up_valid(sum_valid_pipe[0] && stage_valid[15]),
        .res(final_result), .down_valid(final_down_valid),
        .busy(), .error()
    );

    // Output stage
    always_ff @(posedge clk) begin
        if (rst) begin
            res_vld <= 1'b0;
        end else if (pipe_enable) begin
            res_vld <= final_down_valid;
            if (final_down_valid) begin
                res <= final_result;
            end
        end
    end

endmodule
