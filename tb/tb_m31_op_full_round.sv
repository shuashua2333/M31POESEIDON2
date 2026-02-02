`timescale 1ns/1ps

import m31_pkg::*;

// Testbench for m31_op_full_round module
// Tests full round operation with reference vectors from Rust implementation

module tb_m31_op_full_round;

    // Parameters
    parameter int WIDTH = 16;
    parameter int CLK_PERIOD = 10;
    
    // DUT signals
    logic clk;
    logic rst_n;
    m31_t [WIDTH-1:0] state_i;
    m31_t [WIDTH-1:0] const_i;
    m31_t [WIDTH-1:0] state_o;
    
    // Test vectors
    logic [30:0] expected_output [WIDTH-1:0];
    logic [30:0] after_add_expected [WIDTH-1:0];
    logic [30:0] after_sbox_expected [WIDTH-1:0];
    logic [30:0] after_mds_expected [WIDTH-1:0];
    
    // DUT instantiation
    m31_op_full_round #(
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .state_i(state_i),
        .const_i(const_i),
        .state_o(state_o)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        integer i;
        integer errors;
        $display("========================================");
        $display("Full Round Testbench");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        for (i = 0; i < WIDTH; i++) begin
            state_i[i] = 0;
            const_i[i] = 0;
        end
        
        // Reset
        repeat(2) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        
        // Test Case 1: Sequential Input
        $display("Test Case 1: Sequential Input");
        $display("--------------------------------------");
        
        // Input state: [1, 2, 3, ..., 16]
        for (i = 0; i < WIDTH; i++) begin
            state_i[i] = i + 1;
        end
        
        // Round constants: [100, 200, 300, ..., 1600]
        for (i = 0; i < WIDTH; i++) begin
            const_i[i] = (i + 1) * 100;
        end
        
        // Expected intermediate values from Rust
        // After Add RC
        after_add_expected[0] = 101; after_add_expected[1] = 202;
        after_add_expected[2] = 303; after_add_expected[3] = 404;
        after_add_expected[4] = 505; after_add_expected[5] = 606;
        after_add_expected[6] = 707; after_add_expected[7] = 808;
        after_add_expected[8] = 909; after_add_expected[9] = 1010;
        after_add_expected[10] = 1111; after_add_expected[11] = 1212;
        after_add_expected[12] = 1313; after_add_expected[13] = 1414;
        after_add_expected[14] = 1515; after_add_expected[15] = 1616;
        
        // After S-Box (x^5)
        after_sbox_expected[0] = 1920165913; after_sbox_expected[1] = 1315767100;
        after_sbox_expected[2] = 596365460; after_sbox_expected[3] = 1302357907;
        after_sbox_expected[4] = 449168407; after_sbox_expected[5] = 1903825544;
        after_sbox_expected[6] = 1991736322; after_sbox_expected[7] = 873263731;
        after_sbox_expected[8] = 1035402431; after_sbox_expected[9] = 1488487142;
        after_sbox_expected[10] = 552835622; after_sbox_expected[11] = 792875292;
        after_sbox_expected[12] = 1066367979; after_sbox_expected[13] = 1458536541;
        after_sbox_expected[14] = 1773740551; after_sbox_expected[15] = 27151981;
        
        // After 4x4 MDS
        after_mds_expected[0] = 1096421905; after_mds_expected[1] = 1200703459;
        after_mds_expected[2] = 1893286713; after_mds_expected[3] = 1687411525;
        after_mds_expected[4] = 884878911; after_mds_expected[5] = 367873957;
        after_mds_expected[6] = 366323200; after_mds_expected[7] = 547143608;
        after_mds_expected[8] = 1439526261; after_mds_expected[9] = 21307932;
        after_mds_expected[10] = 1713219399; after_mds_expected[11] = 290829700;
        after_mds_expected[12] = 1866787172; after_mds_expected[13] = 741880107;
        after_mds_expected[14] = 1858874271; after_mds_expected[15] = 43234050;
        
        // Final output (After Mix)
        expected_output[0] = 2089068860; expected_output[1] = 1384985267;
        expected_output[2] = 1282539355; expected_output[3] = 2108546761;
        expected_output[4] = 1877525866; expected_output[5] = 552155765;
        expected_output[6] = 1903059489; expected_output[7] = 968278844;
        expected_output[8] = 284689569; expected_output[9] = 205589740;
        expected_output[10] = 1102472041; expected_output[11] = 711964936;
        expected_output[12] = 711950480; expected_output[13] = 926161915;
        expected_output[14] = 1248126913; expected_output[15] = 464369286;
        
        // Apply inputs
        @(posedge clk);
        
        // Wait for pipeline (S-box has 12 cycles + 1 for output register)
        repeat(13) @(posedge clk);
        
        // Check results
        $display("\nChecking output...");
        errors = 0;
        for (i = 0; i < WIDTH; i++) begin
            if (state_o[i] !== expected_output[i]) begin
                $display("ERROR: state_o[%0d] = %0d, expected %0d", 
                         i, state_o[i], expected_output[i]);
                errors++;
            end
        end
        
        if (errors == 0) begin
            $display("  [PASS] Test Case 1 PASSED");
        end else begin
            $display("  [FAIL] Test Case 1 FAILED with %0d errors", errors);
        end
        
        // Test Case 2: All Zeros
        $display("\n--------------------------------------");
        $display("Test Case 2: All Zeros Input");
        $display("--------------------------------------");
        
        for (i = 0; i < WIDTH; i++) begin
            state_i[i] = 0;
            const_i[i] = 1000;
            expected_output[i] = 136065185;
        end
        
        @(posedge clk);
        repeat(13) @(posedge clk);
        
        errors = 0;
        for (i = 0; i < WIDTH; i++) begin
            if (state_o[i] !== expected_output[i]) begin
                $display("ERROR: state_o[%0d] = %0d, expected %0d", 
                         i, state_o[i], expected_output[i]);
                errors++;
            end
        end
        
        if (errors == 0) begin
            $display("  [PASS] Test Case 2 PASSED");
        end else begin
            $display("  [FAIL] Test Case 2 FAILED with %0d errors", errors);
        end
        
        // Finish simulation
        $display("\n========================================");
        $display("Full Round Testbench Complete");
        $display("========================================\n");
        
        repeat(5) @(posedge clk);
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
