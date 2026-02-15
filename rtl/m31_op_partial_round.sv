`timescale 1ns/1ps
import m31_pkg::*;

module m31_op_partial_round #(
    parameter int WIDTH = 16
) (
    input  logic        clk,
    input  logic        rst_n,
    input  m31_t [WIDTH-1:0] state_i,
    input  m31_t             const_i, // Only one constant for state[0]
    output m31_t [WIDTH-1:0] state_o
);

    // Partial Round:
    // 1. Add Constant (state[0] only)   -- 1 cycle  (m31_add registered)
    // 2. S-Box (state[0] only)          -- 15 cycles (3x m31_sqr/mul @ 5cy)
    // 3. Internal Linear Layer          -- 2 cycles  (pipelined: sum + apply)
    //
    // Total Latency: 1 + 15 + 2 = 18 cycles (matching full round)

    // --- Step 1 & 2: S-Box on Element 0 ---
    
    m31_t sbox_out_0;
    m31_t added_0;
    
    m31_add u_add_rc (
        .clk(clk),
        .rst_n(rst_n),
        .a_i(state_i[0]),
        .b_i(const_i),
        .res_o(added_0)
    );
    
    m31_sbox u_sbox (
        .clk(clk),
        .rst_n(rst_n),
        .in_i(added_0),
        .out_o(sbox_out_0)
    );
    
    // --- Delay line for elements 1..WIDTH-1 ---
    // add_rc latency = 1 cycle, S-Box latency = 15 cycles
    // Total delay needed = 1 + 15 = 16 cycles
    
    m31_t [WIDTH-1:0] aligned_state;
    
    logic [30:0] delay_regs [WIDTH-1:1][15:0]; // 16 stages
    
    always_ff @(posedge clk) begin
        // No reset for SRL inference
        for (int i = 1; i < WIDTH; i++) begin
            delay_regs[i][0] <= state_i[i];
            for (int k = 1; k < 16; k++) begin
                delay_regs[i][k] <= delay_regs[i][k-1];
            end
        end
    end
    
    assign aligned_state[0] = sbox_out_0;
    generate
        for (genvar i = 1; i < WIDTH; i++) begin : gen_align
            assign aligned_state[i] = delay_regs[i][15];
        end
    endgenerate
    
    // --- Step 3: Internal Linear Layer (Pipelined: 2 stages) ---
    
    function automatic m31_t add_func(m31_t a, m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction
    
    function automatic m31_t sub_func(m31_t a, m31_t b);
        logic [30:0] b_inv = ~b;
        logic [31:0] s = {1'b0, a} + {1'b0, b_inv};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction
    
    function automatic m31_t double_func(m31_t a);
        return {a[29:0], a[30]};
    endfunction

    function automatic m31_t shift_calc(m31_t a, int sh);
        logic [61:0] wide = {a, a};
        return wide[(31-sh) +: 31];
    endfunction

    // --- Pipeline Stage A (cycle 17): Compute global_sum + register aligned_state ---
    // Use tree reduction for global_sum to reduce combinational depth
    m31_t global_sum_reg;
    m31_t global_sum_comb;
    m31_t [WIDTH-1:0] aligned_state_reg;
    
    always_comb begin : comb_stage_a
        automatic m31_t sum_part [3:0];
        // 4-way partial sums (4 elements each) — depth = 4 adds
        for (int k = 0; k < 4; k++) begin
            sum_part[k] = '0;
            for (int j = k*4; j < (k+1)*4 && j < WIDTH; j++) begin
                sum_part[k] = add_func(sum_part[k], aligned_state[j]);
            end
        end
        // Combine: 2 more adds — total depth = 6 adds (was 16)
        global_sum_comb = add_func(add_func(sum_part[0], sum_part[1]),
                                   add_func(sum_part[2], sum_part[3]));
    end
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            global_sum_reg <= '0;
            for (int i = 0; i < WIDTH; i++)
                aligned_state_reg[i] <= '0;
        end else begin
            global_sum_reg <= global_sum_comb;
            aligned_state_reg <= aligned_state;
        end
    end
    
    // --- Pipeline Stage B (cycle 18): Compute per-element output ---
    m31_t [WIDTH-1:0] res_comb_b;
    integer sh;
    m31_t shifted_val;
    
    always_comb begin
        res_comb_b[0] = sub_func(global_sum_reg, double_func(aligned_state_reg[0]));
        
        for (int i = 1; i < WIDTH; i++) begin
            if (WIDTH == 16) sh = SHIFTS_16[i-1];
            else             sh = SHIFTS_24[i-1];
            
            shifted_val = shift_calc(aligned_state_reg[i], sh);
            res_comb_b[i] = add_func(global_sum_reg, shifted_val);
        end
    end
    
    // Output register (cycle 18)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++) begin
                state_o[i] <= '0;
            end
        end else begin
            state_o <= res_comb_b;
        end
    end

    // Total Latency: 1 (add_rc) + 15 (S-box) + 1 (sum + reg) + 1 (apply + reg) = 18 cycles

endmodule
