`timescale 1ns/1ps
import m31_pkg::*;

module m31_add (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t        a_i,
    input  m31_t        b_i,
    output m31_t        res_o
);

    // M31 Addition A + B mod (2^31 - 1)
    // Latency: 1 cycle (registered output)
    // Optimization: End-around carry.
    
    logic [31:0] sum_raw;
    logic [30:0] sum_folded;
    m31_t        res_comb;
    
    // Combinational logic for M31 addition
    always_comb begin
        sum_raw = {1'b0, a_i} + {1'b0, b_i};
        
        // End-around carry: sum[30:0] + sum[31]
        sum_folded = sum_raw[30:0] + {30'd0, sum_raw[31]};
        
        // Canonical reduction: if sum_folded == P, return 0
        if (sum_folded == P_M31) begin
            res_comb = '0;
        end else begin
            res_comb = sum_folded;
        end
    end
    
    // Output register
    always_ff @(posedge clk) begin
        if (!rst_n)
            res_o <= '0;
        else
            res_o <= res_comb;
    end

endmodule

