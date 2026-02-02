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
    // Latency: 4 Cycles (Fixed)
    // Target Fmax: > 500MHz on UltraScale+
    
    // --- Stage 1 & 2: Multiplication ---
    // We rely on synthesis to map this 31x31 mult to DSPs.
    // Standard DSP48E2 is 27x18. 31x31 takes ~4 DSPs.
    // We provide 2 pipeline registers for the multiplier to ensure DSP P-registers are used.
    
    logic [61:0] prod_st0;
    logic [61:0] prod_st1;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prod_st0 <= '0;
            prod_st1 <= '0;
        end else begin
            // Stage 0: Input * Input (Register optimization will happen here)
            // Note: For best DSP usage, we might want to register inputs explicitly too.
            // But let's assume `a_i` comes from a register.
            // We calculate product.
            // Using retiming, synthesis allows putting registers inside DSP.
            prod_st0 <= mul_wide(a_i, b_i);
            prod_st1 <= prod_st0;
        end
    end
    
    function automatic logic [61:0] mul_wide(input [30:0] a, input [30:0] b);
        // Zero-extend inputs to 62 bits and multiply
        return {31'b0, a} * {31'b0, b};
    endfunction
    
    // --- Stage 3: Split & Add (Reduction Step 1) ---
    // A*B = H*2^31 + L == H + L (mod 2^31 - 1)
    
    logic [30:0] h_st2;
    logic [30:0] l_st2;
    logic [31:0] sum_st2; 
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            h_st2 <= '0;
            l_st2 <= '0;
        end else begin
            h_st2 <= prod_st1[61:31];
            l_st2 <= prod_st1[30:0];
        end
        // Pre-adder in this stage? Or next?
        // Let's do adder here.
        // H + L.
    end
    
    // Wait, let's optimize Stage 3 logic:
    // We can do the add directly from prod_st1 registers.
    logic [31:0] sum_st3;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sum_st3 <= '0;
        end else begin
            sum_st3 <= {1'b0, prod_st1[61:31]} + {1'b0, prod_st1[30:0]};
        end
    end
    
    // --- Stage 4: Final Canonical Reduction ---
    // sum_st3 can be up to (2^31-1) + (2^31-1) = 2^32 - 2.
    // If sum >= P, subtract P. (Or logic: sum_folded = sum[30:0] + sum[31])
    
    m31_t res_st4;
    logic [30:0] sum_final; // Moved outside always_ff for Vivado compatibility
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            res_st4 <= '0;
        end else begin
            // End-around carry
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
    // cycle 1: prod_st0
    // cycle 2: prod_st1
    // cycle 3: sum_st3 (inputs from prod_st1)
    // cycle 4: res_st4 (inputs from sum_st3)
    // Output valid after 4 clocks.

endmodule
