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
    
    // Overall pipeline control
    logic pipeline_advance;
    assign pipeline_advance = res_rdy | ~res_vld;
    assign arg_rdy = pipeline_advance;  // Can always accept new inputs
    
    // 21-stage pipeline (to handle the full computation latency)
    logic [20:0] stage_vld;
    logic [FLEN-1:0] a_pipe [0:20];
    logic [FLEN-1:0] b_pipe [0:20];
    logic [FLEN-1:0] c_pipe [0:20];
    
    // Intermediate results storage
    logic [FLEN-1:0] a2_result, a3_result, a4_result, a5_result;
    logic [FLEN-1:0] b_scaled_result, sum_result;
    logic [FLEN-1:0] a2_pipe [0:20];
    logic [FLEN-1:0] b_scaled_pipe [0:20];
    
    // Arithmetic module outputs
    logic [FLEN-1:0] mult1_res, mult2_res, mult3_res, mult4_res;
    logic [FLEN-1:0] scale_res, add_res, sub_res;
    logic mult1_down, mult2_down, mult3_down, mult4_down;
    logic scale_down, add_down, sub_down;
    
    // Pipeline advancement
    always_ff @(posedge clk) begin
        if (rst) begin
            stage_vld <= 21'b0;
        end else if (pipeline_advance) begin
            stage_vld[20:1] <= stage_vld[19:0];
            stage_vld[0] <= arg_vld;
        end
    end
    
    // Data pipeline
    always_ff @(posedge clk) begin
        if (pipeline_advance) begin
            // Input stage
            a_pipe[0] <= a;
            b_pipe[0] <= b;
            c_pipe[0] <= c;
            
            // Shift pipeline data
            for (int i = 1; i <= 20; i++) begin
                a_pipe[i] <= a_pipe[i-1];
                b_pipe[i] <= b_pipe[i-1];
                c_pipe[i] <= c_pipe[i-1];
            end
            
            // Capture and shift intermediate results
            if (mult1_down) begin
                a2_result <= mult1_res;
            end
            a2_pipe[0] <= a2_result;
            for (int i = 1; i <= 20; i++) begin
                a2_pipe[i] <= a2_pipe[i-1];
            end
            
            if (scale_down) begin
                b_scaled_result <= scale_res;
            end
            b_scaled_pipe[0] <= b_scaled_result;
            for (int i = 1; i <= 20; i++) begin
                b_scaled_pipe[i] <= b_scaled_pipe[i-1];
            end
            
            if (mult2_down) begin
                a3_result <= mult2_res;
            end
            if (mult3_down) begin
                a4_result <= mult3_res;
            end
            if (mult4_down) begin
                a5_result <= mult4_res;
            end
            if (add_down) begin
                sum_result <= add_res;
            end
        end
    end
    
    // Arithmetic modules
    
    // Stage 1: a * a = a^2 (starts at cycle 0, result at cycle 3)
    f_mult mult1 (
        .clk(clk), .rst(rst),
        .a(a_pipe[0]), .b(a_pipe[0]),
        .up_valid(stage_vld[0]),
        .res(mult1_res), .down_valid(mult1_down),
        .busy(), .error()
    );
    
    // Parallel: 0.3 * b (starts at cycle 0, result at cycle 3)
    f_mult scale_mult (
        .clk(clk), .rst(rst),
        .a(CONST_0_3), .b(b_pipe[0]),
        .up_valid(stage_vld[0]),
        .res(scale_res), .down_valid(scale_down),
        .busy(), .error()
    );
    
    // Stage 2: a^2 * a = a^3 (starts at cycle 3, result at cycle 6)
    f_mult mult2 (
        .clk(clk), .rst(rst),
        .a(a2_pipe[0]), .b(a_pipe[3]),
        .up_valid(stage_vld[3]),
        .res(mult2_res), .down_valid(mult2_down),
        .busy(), .error()
    );
    
    // Stage 3: a^3 * a = a^4 (starts at cycle 6, result at cycle 9)
    f_mult mult3 (
        .clk(clk), .rst(rst),
        .a(a3_result), .b(a_pipe[6]),
        .up_valid(stage_vld[6]),
        .res(mult3_res), .down_valid(mult3_down),
        .busy(), .error()
    );
    
    // Stage 4: a^4 * a = a^5 (starts at cycle 9, result at cycle 12)
    f_mult mult4 (
        .clk(clk), .rst(rst),
        .a(a4_result), .b(a_pipe[9]),
        .up_valid(stage_vld[9]),
        .res(mult4_res), .down_valid(mult4_down),
        .busy(), .error()
    );
    
    // Stage 5: a^5 + 0.3*b (starts at cycle 12, result at cycle 15)
    f_add adder (
        .clk(clk), .rst(rst),
        .a(a5_result), .b(b_scaled_pipe[9]),  // b_scaled from 9 cycles ago
        .up_valid(stage_vld[12]),
        .res(add_res), .down_valid(add_down),
        .busy(), .error()
    );
    
    // Stage 6: result - c (starts at cycle 15, result at cycle 18)
    f_sub subtractor (
        .clk(clk), .rst(rst),
        .a(sum_result), .b(c_pipe[15]),
        .up_valid(stage_vld[15]),
        .res(sub_res), .down_valid(sub_down),
        .busy(), .error()
    );
    
    // Output
    always_ff @(posedge clk) begin
        if (rst) begin
            res_vld <= 1'b0;
        end else if (pipeline_advance) begin
            res_vld <= stage_vld[18];
            if (sub_down) begin
                res <= sub_res;
            end
        end
    end

endmodule
