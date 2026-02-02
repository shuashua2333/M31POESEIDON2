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
    // 1. Add Constant (state[0] only)
    // 2. S-Box (state[0] only)
    // 3. Internal Linear Layer (Global)

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
    
    // For other elements, we need to match the Delay of the SBox (12 cycles)
    // to align them with sbox_out_0 before the Linear Layer.
    
    m31_t [WIDTH-1:0] aligned_state;
    
    // Delay Line for indices 1..WIDTH-1
    // Depth: 12 cycles.
    
    logic [30:0] delay_regs [WIDTH-1:1][11:0]; // [Index][Depth]
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 1; i < WIDTH; i++) begin
                for (int k = 0; k < 12; k++) begin
                    delay_regs[i][k] <= '0;
                end
            end
        end else begin
            for (int i = 1; i < WIDTH; i++) begin
                delay_regs[i][0] <= state_i[i];
                for (int k = 1; k < 12; k++) begin
                    delay_regs[i][k] <= delay_regs[i][k-1];
                end
            end
        end
    end
    
    assign aligned_state[0] = sbox_out_0;
    generate
        for (genvar i = 1; i < WIDTH; i++) begin : gen_align
            assign aligned_state[i] = delay_regs[i][11];
        end
    endgenerate
    
    // --- Step 3: Internal Linear Layer ---
    // 1 + Diag(V)
    // Sum = sum(aligned_state)
    // Out[0] = Sum - 2*aligned_state[0]
    // Out[i] = Sum + aligned_state[i] * 2^{Shift[i]}
    
    function automatic m31_t add_func(m31_t a, m31_t b);
        logic [31:0] s = {1'b0, a} + {1'b0, b};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction
    
    function automatic m31_t sub_func(m31_t a, m31_t b);
        // a - b mod P. a + ~b.
        logic [30:0] b_inv = ~b;
        logic [31:0] s = {1'b0, a} + {1'b0, b_inv};
        logic [30:0] f = s[30:0] + {30'd0, s[31]};
        return (f == P_M31) ? '0 : f;
    endfunction
    
    function automatic m31_t double(m31_t a);
        return {a[29:0], a[30]};
    endfunction

    // Shift function (cyclic)
    function automatic m31_t shift_calc(m31_t a, int sh);
        // Concatenate to form a 62-bit window
        logic [61:0] wide = {a, a};
        // Extract 31 bits starting from offset '31-sh' to perform cyclic shift LEFT (multiply by 2^sh)
        // wide[sh +: 31] resulted in right shift/rotate.
        // We need wide[(31-sh) +: 31].
        return wide[(31-sh) +: 31];
    endfunction

    // 1. Calculate Sum
    m31_t global_sum;
    m31_t acc; // Moved outside always_comb for Vivado
    
    always_comb begin
        acc = '0;
        for (int i=0; i<WIDTH; i++) begin
            acc = add_func(acc, aligned_state[i]);
        end
        global_sum = acc;
    end
    
    // 2. Output Logic
    m31_t [WIDTH-1:0] res_comb;
    integer sh; // Moved outside always_comb for Vivado
    m31_t shifted_val; // Moved outside always_comb for Vivado
    
    always_comb begin
        // Index 0: Sum - 2*S0
        res_comb[0] = sub_func(global_sum, double(aligned_state[0]));
        
        // Index 1..WIDTH-1
        for (int i=1; i<WIDTH; i++) begin
            if (WIDTH == 16) sh = SHIFTS_16[i-1];
            else             sh = SHIFTS_24[i-1];
            
            shifted_val = shift_calc(aligned_state[i], sh);
            
            res_comb[i] = add_func(global_sum, shifted_val);
        end
    end
    
    // Register Output
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < WIDTH; i++) begin
                state_o[i] <= '0;
            end
        end else begin
            state_o <= res_comb;
        end
    end

endmodule
