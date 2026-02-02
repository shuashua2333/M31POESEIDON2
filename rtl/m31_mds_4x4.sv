`timescale 1ns/1ps
import m31_pkg::*;

module m31_mds_4x4 (
    input  m31_t [3:0] state_i,
    output m31_t [3:0] state_o
);

    // Implements the 4x4 MDS matrix permutation optimized for Poseidon2
    // Matrix:
    // [ 2 3 1 1 ]
    // [ 1 2 3 1 ]
    // [ 1 1 2 3 ]
    // [ 3 1 1 2 ]
    
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

    // Intermediate signals based on Rust optimized implementation
    m31_t t01, t23, t0123;
    m31_t t01123, t01233;
    
    // Logic
    always_comb begin
        // let t01 = x[0] + x[1];
        t01 = add(state_i[0], state_i[1]);
        
        // let t23 = x[2] + x[3];
        t23 = add(state_i[2], state_i[3]);
        
        // let t0123 = t01 + t23;
        t0123 = add(t01, t23);
        
        // let t01123 = t0123 + x[1];
        t01123 = add(t0123, state_i[1]);
        
        // let t01233 = t0123 + x[3];
        t01233 = add(t0123, state_i[3]);
        
        // x[3] = t01233 + 2*x[0];
        state_o[3] = add(t01233, double(state_i[0]));
        
        // x[1] = t01123 + 2*x[2];
        state_o[1] = add(t01123, double(state_i[2]));
        
        // x[0] = t01123 + t01;
        state_o[0] = add(t01123, t01);
        
        // x[2] = t01233 + t23;
        state_o[2] = add(t01233, t23);
    end

endmodule
