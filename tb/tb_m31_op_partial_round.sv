`timescale 1ns/1ps

import m31_pkg::*;

// Testbench for m31_op_partial_round module
// Tests partial round operation with reference vectors from Rust implementation

module tb_m31_op_partial_round;

    // Parameters
    parameter int WIDTH = 16;
    parameter int CLK_PERIOD = 10;
    
    // DUT signals
    logic clk;
    logic rst_n;
    m31_t [WIDTH-1:0] state_i;
    m31_t const_i;
    m31_t [WIDTH-1:0] state_o;
    
    // Test vectors
    logic [30:0] expected_output [WIDTH-1:0];
    logic [30:0] after_add_0_expected;
    logic [30:0] after_sbox_0_expected;
    logic [30:0] before_linear_expected [WIDTH-1:0];
    
    // DUT instantiation
    m31_op_partial_round #(
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
        $display("Partial Round Testbench");
        $display("========================================\n");
        
        // Initialize
        rst_n = 0;
        for (i = 0; i < WIDTH; i++) begin
            state_i[i] = 0;
        end
        const_i = 0;
        
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
        
        // Round constant (only for state[0])
        const_i = 12345;
        
        // Expected intermediate values from Rust
        after_add_0_expected = 12346;
        after_sbox_0_expected = 849333766;
        
        // Before linear layer
        before_linear_expected[0] = 849333766;
        for (i = 1; i < WIDTH; i++) begin
            before_linear_expected[i] = i + 1;
        end
        
        // Final output (After Internal Linear Layer)
        expected_output[0] = 1298150016;
        expected_output[1] = 849333903;
        expected_output[2] = 849333907;
        expected_output[3] = 849333917;
        expected_output[4] = 849333941;
        expected_output[5] = 849333997;
        expected_output[6] = 849334125;
        expected_output[7] = 849334413;
        expected_output[8] = 849335053;
        expected_output[9] = 849336461;
        expected_output[10] = 849345165;
        expected_output[11] = 849383053;
        expected_output[12] = 849440397;
        expected_output[13] = 849563277;
        expected_output[14] = 849825421;
        expected_output[15] = 850382477;
        
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
        
        // Test Case 2: Large Values
        $display("\n--------------------------------------");
        $display("Test Case 2: Large Values");
        $display("--------------------------------------");
        
        for (i = 0; i < WIDTH; i++) begin
            state_i[i] = 2147483646;
        end
        const_i = 1;
        
        // Expected output from Rust
        expected_output[0] = 2147483632;
        expected_output[1] = 2147483631;
        expected_output[2] = 2147483630;
        expected_output[3] = 2147483628;
        expected_output[4] = 2147483624;
        expected_output[5] = 2147483616;
        expected_output[6] = 2147483600;
        expected_output[7] = 2147483568;
        expected_output[8] = 2147483504;
        expected_output[9] = 2147483376;
        expected_output[10] = 2147482608;
        expected_output[11] = 2147479536;
        expected_output[12] = 2147475440;
        expected_output[13] = 2147467248;
        expected_output[14] = 2147450864;
        expected_output[15] = 2147418096;
        
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
        $display("Partial Round Testbench Complete");
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
