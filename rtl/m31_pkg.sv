`timescale 1ns/1ps
package m31_pkg;

    // M31 Prime: 2^31 - 1
    localparam bit [30:0] P_M31 = 31'h7FFFFFFF;

    // Type definition for M31 elements
    // strict 31-bit width to ensure tools optimize for this boundary
    typedef logic [30:0] m31_t;

    // Commonly used constants
    localparam m31_t ZERO = 31'd0;
    localparam m31_t ONE  = 31'd1;

    // Poseidon2 Shifts
    // Poseidon2 Shifts
    typedef byte unsigned shifts_16_t [0:14];
    typedef byte unsigned shifts_24_t [0:22];

    // Note: These arrays map to indices 1..N-1.
    localparam shifts_16_t SHIFTS_16 = '{0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16};
    
    localparam shifts_24_t SHIFTS_24 = '{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22};


endpackage
