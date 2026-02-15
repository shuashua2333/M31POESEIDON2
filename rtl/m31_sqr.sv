`timescale 1ns/1ps
import m31_pkg::*;

module m31_sqr (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t        a_i,
    output m31_t        res_o
);

    // M31 Squaring: A * A mod (2^31 - 1)
    // Optimized version of m31_mul for squaring.
    // Latency: 5 Cycles (Matching m31_mul)
    // Pipeline: InputReg → Square → SquarePipe → Reduce1 → Reduce2
    
    // --- Stage 0: Register Input ---
    logic [30:0] a_reg;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_reg <= '0;
        end else begin
            a_reg <= a_i;
        end
    end
    
    // --- Stage 1 & 2: Squaring ---
    logic [61:0] sqr_st1;
    logic [61:0] sqr_st2;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sqr_st1 <= '0;
            sqr_st2 <= '0;
        end else begin
            sqr_st1 <= {31'b0, a_reg} * {31'b0, a_reg};
            sqr_st2 <= sqr_st1;
        end
    end
    
    // --- Stage 3: Split & Add (Reduction Step 1) ---
    logic [31:0] sum_st3;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sum_st3 <= '0;
        end else begin
            sum_st3 <= {1'b0, sqr_st2[61:31]} + {1'b0, sqr_st2[30:0]};
        end
    end
    
    // --- Stage 4: Final Canonical Reduction ---
    m31_t res_st4;
    logic [30:0] sum_final;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            res_st4 <= '0;
        end else begin
            sum_final = sum_st3[30:0] + {30'd0, sum_st3[31]};
            
            if (sum_final == P_M31) begin
                res_st4 <= '0;
            end else begin
                res_st4 <= sum_final;
            end
        end
    end

    assign res_o = res_st4;

    // Total Latency:
    // cycle 0: a_reg (input register)
    // cycle 1: sqr_st1 (square)
    // cycle 2: sqr_st2 (square pipeline)
    // cycle 3: sum_st3 (H + L reduction)
    // cycle 4: res_st4 (canonical reduction)
    // Output valid after 5 clocks.

endmodule
