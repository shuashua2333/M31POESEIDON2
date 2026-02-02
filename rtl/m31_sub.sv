`timescale 1ns/1ps
import m31_pkg::*;

module m31_sub (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t        a_i,
    input  m31_t        b_i,
    output m31_t        res_o
);

    // M31 Subtraction A - B mod (2^31 - 1)
    // Uses identity: A - B = A + (P - B) = A + ~B (since P - B = ~B for 31-bit B)
    
    logic [30:0] b_inv;
    logic [31:0] sum_raw;
    logic [30:0] sum_folded;
    m31_t        res_comb;
    
    always_comb begin
        // P - B = ~B for M31
        b_inv = ~b_i;
        
        // Add A + ~B
        sum_raw = {1'b0, a_i} + {1'b0, b_inv};
        
        // End-around carry
        sum_folded = sum_raw[30:0] + {30'd0, sum_raw[31]};
        
        // Canonical reduction
        if (sum_folded == P_M31)
            res_comb = '0;
        else
            res_comb = sum_folded;
    end
    
    assign res_o = res_comb;

endmodule

