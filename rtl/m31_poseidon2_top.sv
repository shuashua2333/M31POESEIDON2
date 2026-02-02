`timescale 1ns/1ps
import m31_pkg::*;
import m31_constants_pkg::*;

module m31_poseidon2_top #(
    parameter int WIDTH = 16,
    parameter int N_FULL_ROUNDS_HALF = 4, // Total 8 Full Rounds usually
    parameter int N_PARTIAL_ROUNDS = 14   // Example
) (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t [WIDTH-1:0] state_i, // Plain M31 elements
    output m31_t [WIDTH-1:0] state_o
);

    // Pipeline Structure:
    // 1. Initial MDS (mds_light)
    // 2. Initial Full Rounds (N_FULL/2)
    // 3. Partial Rounds (N_PARTIAL)
    // 4. Terminal Full Rounds (N_FULL/2)
    
    // Wires for chaining
    // Total stages: 1 (PreMDS) + N_FULL_HALF + N_PARTIAL + N_FULL_HALF.
    // Let's name wires dynamically? No, simple array of wires.
    
    // Definitions
    typedef m31_t [WIDTH-1:0] state_array_t;
    
    // --- Stage 0: Pre-MDS (mds_light) ---
    // Rust: external_initial_permute_state calls mds_light FIRST.
    // It is just the linear layer. Combinational or registered?
    // mds_light in our full_round is part of the Step 3.
    // We can instantiate just the MDS part.
    // Or we use m31_mds_4x4 directly.
    
    state_array_t pre_mds_out;
    // We need the mixing logic too.
    // Let's create a helper module `m31_linear_external` to avoid code duplication?
    // Or just copy logic here.
    
    // Implementing Pre-MDS logic locally (pipelined 1 stage)
    state_array_t mds_4x4_res;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i += 4) begin : gen_pre_mds
            m31_mds_4x4 u_mds (
                .state_i(state_i[i+3 : i]),
                .state_o(mds_4x4_res[i+3 : i])
            );
        end
    endgenerate
    
    // Mixing for Pre-MDS
    state_array_t pre_mds_mixed;
    
    m31_mix_layer #(.WIDTH(WIDTH)) u_mix_pre (
        .state_i(mds_4x4_res),
        .state_o(pre_mds_mixed)
    );
    
    // Register after Pre-MDS
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++) begin
                pre_mds_out[i] <= '0;
            end
        end else begin
            pre_mds_out <= pre_mds_mixed;
        end
    end
    
    // Helper function for local add
    function automatic m31_t add_m31(m31_t a, m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction

    // --- Chain Logic ---
    state_array_t [N_FULL_ROUNDS_HALF:0]   chain_initial;
    state_array_t [N_PARTIAL_ROUNDS:0]     chain_partial;
    state_array_t [N_FULL_ROUNDS_HALF:0]   chain_terminal;
    
    assign chain_initial[0] = pre_mds_out;
    
    // 1. Initial Full Rounds
    generate
        for (i = 0; i < N_FULL_ROUNDS_HALF; i++) begin : gen_r_init
            m31_op_full_round #(.WIDTH(WIDTH)) u_fr (
                .clk(clk),
                .rst_n(rst_n),
                .state_i(chain_initial[i]),
                .const_i(ROUND_CONSTS_INITIAL[i]), // Connected Real Constants
                .state_o(chain_initial[i+1])
            );
        end
    endgenerate
    
    assign chain_partial[0] = chain_initial[N_FULL_ROUNDS_HALF];
    
    // 2. Partial Rounds
    generate
        for (i = 0; i < N_PARTIAL_ROUNDS; i++) begin : gen_r_part
            m31_op_partial_round #(.WIDTH(WIDTH)) u_pr (
                .clk(clk),
                .rst_n(rst_n),
                .state_i(chain_partial[i]),
                .const_i(ROUND_CONSTS_INTERNAL[i]), // Connected Real Constants
                .state_o(chain_partial[i+1])
            );
        end
    endgenerate
    
    assign chain_terminal[0] = chain_partial[N_PARTIAL_ROUNDS];

    // 3. Terminal Full Rounds
    generate
        for (i = 0; i < N_FULL_ROUNDS_HALF; i++) begin : gen_r_term
            m31_op_full_round #(.WIDTH(WIDTH)) u_fr (
                .clk(clk),
                .rst_n(rst_n),
                .state_i(chain_terminal[i]),
                .const_i(ROUND_CONSTS_TERMINAL[i]), // Connected Real Constants
                .state_o(chain_terminal[i+1])
            );
        end
    endgenerate

    assign state_o = chain_terminal[N_FULL_ROUNDS_HALF];

endmodule
