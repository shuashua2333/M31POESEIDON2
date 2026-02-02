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
    // 1. Add Round Constants
    // 2. S-Box (All elements)
    // 3. MDS Light (4x4 + Mixing)

    // --- Step 1 & 2: Add + SBox ---
    m31_t [WIDTH-1:0] sbox_out;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_sbox
            m31_t added;
            
            // Instantiating Adder
            m31_add u_add_rc (
                .clk(clk), // Actually add is comb in our def, but let's connect clk if we change it later
                .rst_n(rst_n),
                .a_i(state_i[i]),
                .b_i(const_i[i]), // Constant is input
                .res_o(added)
            );
            
            // Instantiating S-Box (12 cycle latency)
            m31_sbox u_sbox (
                .clk(clk),
                .rst_n(rst_n),
                .in_i(added),
                .out_o(sbox_out[i])
            );
        end
    endgenerate
    
    // --- Step 3: MDS Light ---
    // A. Apply 4x4 MDS to chunks
    // B. Calculate Sums
    // C. Add Sums
    
    // This part can be pipelined or combinatorial.
    // Given S-Box is deep (12 cycles), maybe we can make Linear layer combinatorial to save regs,
    // or add 1 stage. Let's make it combinatorial for now, as shifts/adds are fast.
    
    // A. 4x4 MDS
    m31_t [WIDTH-1:0] mds_main_out;
    
    generate
        for (i = 0; i < WIDTH; i += 4) begin : gen_mds4
            m31_mds_4x4 u_mds4 (
                .state_i(sbox_out[i+3 : i]),
                .state_o(mds_main_out[i+3 : i])
            );
        end
    endgenerate
    
    // B & C. Mixing Step (Sums + Add)
    m31_t [WIDTH-1:0] mix_out;
    
    m31_mix_layer #(.WIDTH(WIDTH)) u_mix_internal (
        .state_i(mds_main_out), // Output from 4x4 MDS
        .state_o(mix_out)
    );

    // Register Output
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++) begin
                state_o[i] <= '0;
            end
        end else begin
            state_o <= mix_out;
        end
    end

endmodule
