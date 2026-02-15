`timescale 1ns/1ps
import m31_pkg::*;

module m31_mix_layer #(
    parameter int WIDTH = 16
) (
    input  logic                clk,
    input  logic                rst_n,
    input  m31_t [WIDTH-1:0]    state_i,
    output m31_t [WIDTH-1:0]    state_o
);

    // Mixing Step:
    // 1. Calculate Sums[k] where k in 0..3
    //    sums[k] = sum(state_i[j] where j % 4 == k)
    // 2. state_o[i] = state_i[i] + sums[i%4]
    //
    // Latency: 1 cycle (registered output)

    m31_t [3:0] sums;
    m31_t [WIDTH-1:0] result_comb;

    // Helper function for add
    function automatic m31_t add_func(m31_t a, m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction

    always_comb begin
        // Calculate Sums
        for (int k=0; k<4; k++) begin
            m31_t acc;
            acc = '0;
            for (int j=k; j<WIDTH; j+=4) begin
                acc = add_func(acc, state_i[j]);
            end
            sums[k] = acc;
        end

        // Add Sums to State
        for (int i=0; i<WIDTH; i++) begin
            result_comb[i] = add_func(state_i[i], sums[i%4]);
        end
    end

    // Pipeline register
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++) begin
                state_o[i] <= '0;
            end
        end else begin
            state_o <= result_comb;
        end
    end

endmodule
