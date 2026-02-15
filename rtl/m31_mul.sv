`timescale 1ns/1ps
import m31_pkg::*;

module m31_mul (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t        a_i,
    input  m31_t        b_i,
    output m31_t        res_o
);

    // M31 Multiplication: A * B mod (2^31 - 1)
    // Latency: 5 Cycles (Fixed)
    // Pipeline: InputReg → Mult → MultPipe → Reduce1 → Reduce2
    // Target Fmax: > 200MHz on UltraScale+
    
    // --- Stage 0: Register Inputs (DSP A/B input registers) ---
    logic [30:0] a_reg, b_reg;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            a_reg <= '0;
            b_reg <= '0;
        end else begin
            a_reg <= a_i;
            b_reg <= b_i;
        end
    end
    
    // --- Stage 1 & 2: Multiplication ---
    // 31x31 multiply mapped to DSP48E2 cascade (~4 DSPs).
    // Two pipeline registers for DSP M/P registers.
    
    logic [61:0] prod_st1;
    logic [61:0] prod_st2;
    
    function automatic logic [61:0] mul_wide(input [30:0] a, input [30:0] b);
        return {31'b0, a} * {31'b0, b};
    endfunction
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prod_st1 <= '0;
            prod_st2 <= '0;
        end else begin
            prod_st1 <= mul_wide(a_reg, b_reg);
            prod_st2 <= prod_st1;
        end
    end
    
    // --- Stage 3: Split & Add (Reduction Step 1) ---
    // A*B = H*2^31 + L == H + L (mod 2^31 - 1)
    logic [31:0] sum_st3;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sum_st3 <= '0;
        end else begin
            sum_st3 <= {1'b0, prod_st2[61:31]} + {1'b0, prod_st2[30:0]};
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
    // cycle 0: a_reg, b_reg (input register)
    // cycle 1: prod_st1 (multiply)
    // cycle 2: prod_st2 (multiply pipeline)
    // cycle 3: sum_st3 (H + L reduction)
    // cycle 4: res_st4 (canonical reduction)
    // Output valid after 5 clocks.

endmodule
