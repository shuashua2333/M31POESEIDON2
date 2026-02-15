`timescale 1ns/1ps
import m31_pkg::*;
import m31_constants_pkg::*;

module m31_poseidon2_iterative #(
    parameter int WIDTH             = 16,
    parameter int N_FULL_ROUNDS_HALF = 4,
    parameter int N_PARTIAL_ROUNDS   = 14
) (
    input  logic                clk,
    input  logic                rst_n,
    
    // Input interface
    input  m31_t [WIDTH-1:0]    state_i,
    input  logic                valid_i,
    output logic                ready_o,
    
    // Output interface
    output m31_t [WIDTH-1:0]    state_o,
    output logic                valid_o
);

    // =========================================================================
    // Architecture: Folded/Iterative Poseidon2 (Timing-Optimized)
    // =========================================================================
    // One full-round core + one partial-round core, reused across 22 rounds.
    // Pre-MDS pipelined into 2 registered stages (MDS 4x4 + Mix Layer).
    // Input gating: only the active round core receives data.
    // FSM drives round sequencing. Each round = 19 clock cycles.
    // Total latency = 1 (load) + 2 (pre-MDS) + 22 * 19 (rounds) + 1 (done)
    //              = 422 cycles
    
    localparam int ROUND_LATENCY = 19; // 18 pipeline + 1 feedback
    localparam int TOTAL_ROUNDS  = N_FULL_ROUNDS_HALF * 2 + N_PARTIAL_ROUNDS;
    
    typedef m31_t [WIDTH-1:0] state_array_t;
    
    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [2:0] {
        S_IDLE,
        S_PRE_MDS_1,    // Pre-MDS stage 1: MDS 4x4 registered
        S_PRE_MDS_2,    // Pre-MDS stage 2: Mix Layer registered
        S_ROUND_EXEC,
        S_DONE
    } state_e;
    
    state_e         fsm_state;
    logic [4:0]     round_idx;
    logic [4:0]     cycle_cnt;  // Widened to 5 bits for ROUND_LATENCY=19
    
    // Round type decode (combinational)
    wire round_is_full = (round_idx < N_FULL_ROUNDS_HALF) || 
                         (round_idx >= (N_FULL_ROUNDS_HALF + N_PARTIAL_ROUNDS));
    
    // =========================================================================
    // State Register (iterative feedback)
    // =========================================================================
    state_array_t state_reg;
    
    // =========================================================================
    // Pre-MDS Logic (Pipelined: 2 registered stages)
    // =========================================================================
    
    function automatic m31_t add_m31(m31_t a, m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction
    
    function automatic m31_t double_m31(m31_t a);
        return {a[29:0], a[30]};
    endfunction
    
    // --- Pre-MDS Stage 1: MDS 4x4 (combinational → registered) ---
    state_array_t mds_4x4_comb;
    state_array_t mds_4x4_reg;
    
    genvar gi;
    generate
        for (gi = 0; gi < WIDTH; gi += 4) begin : gen_pre_mds4
            always_comb begin
                automatic m31_t t01   = add_m31(state_i[gi+0], state_i[gi+1]);
                automatic m31_t t23   = add_m31(state_i[gi+2], state_i[gi+3]);
                automatic m31_t t0123 = add_m31(t01, t23);
                automatic m31_t t01123= add_m31(t0123, state_i[gi+1]);
                automatic m31_t t01233= add_m31(t0123, state_i[gi+3]);
                
                mds_4x4_comb[gi+3] = add_m31(t01233, double_m31(state_i[gi+0]));
                mds_4x4_comb[gi+1] = add_m31(t01123, double_m31(state_i[gi+2]));
                mds_4x4_comb[gi+0] = add_m31(t01123, t01);
                mds_4x4_comb[gi+2] = add_m31(t01233, t23);
            end
        end
    endgenerate
    
    // Register MDS 4x4 output (gated: only capture when valid_i in S_IDLE)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++)
                mds_4x4_reg[i] <= '0;
        end else if (fsm_state == S_IDLE && valid_i) begin
            mds_4x4_reg <= mds_4x4_comb;
        end
    end
    
    // --- Pre-MDS Stage 2: Mix Layer (combinational → registered) ---
    state_array_t mix_comb;
    state_array_t pre_mds_reg;
    
    always_comb begin
        automatic m31_t sums [3:0];
        for (int k = 0; k < 4; k++) begin
            sums[k] = '0;
            for (int j = k; j < WIDTH; j += 4) begin
                sums[k] = add_m31(sums[k], mds_4x4_reg[j]);
            end
        end
        for (int i = 0; i < WIDTH; i++) begin
            mix_comb[i] = add_m31(mds_4x4_reg[i], sums[i%4]);
        end
    end
    
    // Register Mix Layer output (gated: only capture during S_PRE_MDS_1)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++)
                pre_mds_reg[i] <= '0;
        end else if (fsm_state == S_PRE_MDS_1) begin
            pre_mds_reg <= mix_comb;
        end
    end
    
    // =========================================================================
    // Round Constants Selection (combinational, small lookup)
    // =========================================================================
    state_array_t full_round_const;
    m31_t         partial_round_const;
    
    always_comb begin
        full_round_const = '0;
        partial_round_const = '0;
        
        if (round_idx < N_FULL_ROUNDS_HALF) begin
            full_round_const = ROUND_CONSTS_INITIAL[round_idx];
        end else if (round_idx < N_FULL_ROUNDS_HALF + N_PARTIAL_ROUNDS) begin
            partial_round_const = ROUND_CONSTS_INTERNAL[round_idx - N_FULL_ROUNDS_HALF];
        end else begin
            full_round_const = ROUND_CONSTS_TERMINAL[round_idx - N_FULL_ROUNDS_HALF - N_PARTIAL_ROUNDS];
        end
    end
    
    // =========================================================================
    // Shared Round Cores (with input gating to reduce fan-out)
    // =========================================================================
    
    state_array_t fr_input;
    state_array_t pr_input;
    state_array_t fr_output;
    state_array_t pr_output;
    
    // Gate: only the active core sees state_reg; the other gets zeros
    // This halves fan-out from state_reg and reduces switching activity
    always_comb begin
        if (round_is_full) begin
            fr_input = state_reg;
            for (int i = 0; i < WIDTH; i++)
                pr_input[i] = '0;
        end else begin
            for (int i = 0; i < WIDTH; i++)
                fr_input[i] = '0;
            pr_input = state_reg;
        end
    end
    
    m31_op_full_round #(.WIDTH(WIDTH)) u_full_round (
        .clk(clk),
        .rst_n(rst_n),
        .state_i(fr_input),
        .const_i(full_round_const),
        .state_o(fr_output)
    );
    
    m31_op_partial_round #(.WIDTH(WIDTH)) u_partial_round (
        .clk(clk),
        .rst_n(rst_n),
        .state_i(pr_input),
        .const_i(partial_round_const),
        .state_o(pr_output)
    );
    
    // =========================================================================
    // FSM + Datapath
    // =========================================================================
    
    assign ready_o = (fsm_state == S_IDLE);
    
    // Output register
    state_array_t state_o_reg;
    logic         valid_o_reg;
    
    assign state_o = state_o_reg;
    assign valid_o = valid_o_reg;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            fsm_state   <= S_IDLE;
            round_idx   <= '0;
            cycle_cnt   <= '0;
            valid_o_reg <= 1'b0;
            for (int i = 0; i < WIDTH; i++) begin
                state_reg[i]   <= '0;
                state_o_reg[i] <= '0;
            end
        end else begin
            // Default: clear valid
            valid_o_reg <= 1'b0;
            
            case (fsm_state)
                S_IDLE: begin
                    if (valid_i) begin
                        // mds_4x4_reg captures MDS 4x4 result at next edge
                        fsm_state <= S_PRE_MDS_1;
                    end
                end
                
                S_PRE_MDS_1: begin
                    // mds_4x4_reg now valid; pre_mds_reg captures mix result at next edge
                    fsm_state <= S_PRE_MDS_2;
                end
                
                S_PRE_MDS_2: begin
                    // pre_mds_reg now has the complete pre-MDS result
                    state_reg <= pre_mds_reg;
                    round_idx <= '0;
                    cycle_cnt <= '0;
                    fsm_state <= S_ROUND_EXEC;
                end
                
                S_ROUND_EXEC: begin
                    if (cycle_cnt == ROUND_LATENCY[4:0] - 5'd1) begin
                        // Round complete: capture output from active core
                        if (round_is_full) begin
                            state_reg <= fr_output;
                        end else begin
                            state_reg <= pr_output;
                        end
                        
                        cycle_cnt <= '0;
                        
                        if (round_idx == TOTAL_ROUNDS[4:0] - 5'd1) begin
                            fsm_state <= S_DONE;
                        end else begin
                            round_idx <= round_idx + 5'd1;
                        end
                    end else begin
                        cycle_cnt <= cycle_cnt + 5'd1;
                    end
                end
                
                S_DONE: begin
                    // Output the final state
                    state_o_reg <= state_reg;
                    valid_o_reg <= 1'b1;
                    fsm_state   <= S_IDLE;
                end
                
                default: begin
                    fsm_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
