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
    // 1. x^2
    // 2. x^4 = (x^2)^2
    // 3. x^5 = x^4 * x
    
    // Latency of m31_mul is 4 cycles.
    // Total latency: 4 (x^2) + 4 (x^4) + 4 (x^5) = 12 cycles.
    
    // Step 1: x^2
    m31_t x2;
    m31_mul u_mul_x2 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(in_i),
        .b_i(in_i),
        .res_o(x2)
    );
    
    // Step 2: x^4
    m31_t x4;
    m31_mul u_mul_x4 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(x2),
        .b_i(x2),
        .res_o(x4)
    );
    
    // Step 3: Delay input x to match x^4 availability (8 cycles)
    m31_t x_delayed;
    
    // 8-stage shift register for x
    // Using simple behavioral SRL inference
    logic [30:0] delay_line [7:0]; 
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                delay_line[i] <= '0;
            end
        end else begin
            delay_line[0] <= in_i;
            for (int i=1; i<8; i++) begin
                delay_line[i] <= delay_line[i-1];
            end
        end
    end
    assign x_delayed = delay_line[7];

    // Step 4: x^5 = x^4 * x
    m31_mul u_mul_x5 (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(x4),
        .b_i(x_delayed),
        .res_o(out_o)
    );

endmodule
