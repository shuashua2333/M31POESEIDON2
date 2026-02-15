`timescale 1ns/1ps
import m31_pkg::*;

module m31_sbox (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t        in_i,
    output m31_t        out_o
);

    // M31 S-Box: x^5
    // Pipelined implementation:
    // 1. x^2          (m31_sqr: 5 cycles)
    // 2. x^4 = (x^2)^2 (m31_sqr: 5 cycles)
    // 3. x^5 = x^4 * x (m31_mul: 5 cycles)
    
    // Total latency: 5 (x^2) + 5 (x^4) + 5 (x^5) = 15 cycles.
    
    // Step 1: x^2
    m31_t x2;
    m31_sqr u_sqr_x2 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(in_i),
        .res_o(x2)
    );
    
    // Step 2: x^4
    m31_t x4;
    m31_sqr u_sqr_x4 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(x2),
        .res_o(x4)
    );
    
    // Step 3: Delay input x to match x^4 availability (10 cycles)
    // x^2 takes 5 cycles, x^4 takes another 5 cycles = 10 total
    m31_t x_delayed;
    
    logic [30:0] delay_line [9:0]; // 10 stages
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 10; i++) begin
                delay_line[i] <= '0;
            end
        end else begin
            delay_line[0] <= in_i;
            for (int i=1; i<10; i++) begin
                delay_line[i] <= delay_line[i-1];
            end
        end
    end
    assign x_delayed = delay_line[9];

    // Step 4: x^5 = x^4 * x
    m31_mul u_mul_x5 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(x4),
        .b_i(x_delayed),
        .res_o(out_o)
    );

    // Total Latency: 5 (x^2) + 5 (x^4) + 5 (x^5) = 15 cycles

endmodule
