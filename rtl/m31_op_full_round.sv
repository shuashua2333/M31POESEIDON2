`timescale 1ns/1ps
import m31_pkg::*;

module m31_op_full_round #(
    parameter int WIDTH = 16
) (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t [WIDTH-1:0] state_i,
    input  m31_t [WIDTH-1:0] const_i,
    output m31_t [WIDTH-1:0] state_o
);

    // Full Round:
    // 1. Add Round Constants   -- 1 cycle  (m31_add registered)
    // 2. S-Box (All elements)  -- 15 cycles (3x m31_sqr/mul @ 5cy each)
    // 3. MDS Light: 4x4 MDS    -- 1 cycle  (registered)
    // 4. Mix Layer              -- 1 cycle  (registered)
    //
    // Total Latency: 1 + 15 + 1 + 1 = 18 cycles

    // --- Step 1 & 2: Add + SBox ---
    m31_t [WIDTH-1:0] sbox_out;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_sbox
            m31_t added;
            
            m31_add u_add_rc (
                .clk(clk),
                .rst_n(rst_n),
                .a_i(state_i[i]),
                .b_i(const_i[i]),
                .res_o(added)
            );
            
            m31_sbox u_sbox (
                .clk(clk),
                .rst_n(rst_n),
                .in_i(added),
                .out_o(sbox_out[i])
            );
        end
    endgenerate
    
    // --- Step 3: MDS Light ---
    // A. 4x4 MDS (1 cycle latency, registered output)
    m31_t [WIDTH-1:0] mds_main_out;
    
    generate
        for (i = 0; i < WIDTH; i += 4) begin : gen_mds4
            m31_mds_4x4 u_mds4 (
                .clk(clk),
                .rst_n(rst_n),
                .state_i(sbox_out[i+3 : i]),
                .state_o(mds_main_out[i+3 : i])
            );
        end
    endgenerate
    
    // B. Mix Layer (1 cycle latency, registered output)
    m31_mix_layer #(.WIDTH(WIDTH)) u_mix_internal (
        .clk(clk),
        .rst_n(rst_n),
        .state_i(mds_main_out),
        .state_o(state_o)
    );

    // Total Latency: 1 (add_rc) + 15 (S-box) + 1 (MDS 4x4) + 1 (Mix) = 18 cycles

endmodule
