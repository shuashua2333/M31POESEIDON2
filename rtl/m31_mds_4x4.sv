`timescale 1ns/1ps
import m31_pkg::*;

module m31_mds_4x4 (
    input  logic       clk,
    input  logic       rst_n,
    input  m31_t [3:0] state_i,
    output m31_t [3:0] state_o
);

    // Implements the 4x4 MDS matrix permutation optimized for Poseidon2
    // Matrix:
    // [ 2 3 1 1 ]
    // [ 1 2 3 1 ]
    // [ 1 1 2 3 ]
    // [ 3 1 1 2 ]
    //
    // Latency: 1 cycle (registered output)
    
    // Helper function for modular addition A+B
    function automatic m31_t add(input m31_t a, input m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction

    // Helper for doubling (multiplication by 2 in M31 is cyclic shift left by 1)
    function automatic m31_t double(input m31_t a);
        return {a[29:0], a[30]};
    endfunction

    // Combinational result
    m31_t [3:0] result_comb;
    
    // Intermediate signals
    m31_t t01, t23, t0123;
    m31_t t01123, t01233;
    
    always_comb begin
        t01 = add(state_i[0], state_i[1]);
        t23 = add(state_i[2], state_i[3]);
        t0123 = add(t01, t23);
        t01123 = add(t0123, state_i[1]);
        t01233 = add(t0123, state_i[3]);
        
        result_comb[3] = add(t01233, double(state_i[0]));
        result_comb[1] = add(t01123, double(state_i[2]));
        result_comb[0] = add(t01123, t01);
        result_comb[2] = add(t01233, t23);
    end

    // Pipeline register
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_o <= '0;
        end else begin
            state_o <= result_comb;
        end
    end

endmodule
