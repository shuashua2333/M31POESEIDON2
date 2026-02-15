`timescale 1ns/1ps

module tb_m31_poseidon2_iterative;
    import m31_pkg::*;
    import m31_constants_pkg::*;

    // Parameters matching the DUT
    localparam int WIDTH = 16;
    localparam int N_FULL_ROUNDS_HALF = 4;
    localparam int N_PARTIAL_ROUNDS = 14;
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // DUT signals
    m31_t [WIDTH-1:0] state_i;
    logic             valid_i;
    logic             ready_o;
    m31_t [WIDTH-1:0] state_o;
    logic             valid_o;
    
    // Expected values
    m31_t [WIDTH-1:0] expected_1;
    m31_t [WIDTH-1:0] expected_2;
    
    // Instantiate DUT
    m31_poseidon2_iterative #(
        .WIDTH(WIDTH),
        .N_FULL_ROUNDS_HALF(N_FULL_ROUNDS_HALF),
        .N_PARTIAL_ROUNDS(N_PARTIAL_ROUNDS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .state_i(state_i),
        .valid_i(valid_i),
        .ready_o(ready_o),
        .state_o(state_o),
        .valid_o(valid_o)
    );
    
    // Clock generation (100MHz for simulation)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Task: Wait for valid_o pulse
    task automatic wait_for_output(input int timeout_cycles);
        integer cnt;
        cnt = 0;
        while (!valid_o && cnt < timeout_cycles) begin
            @(posedge clk);
            cnt = cnt + 1;
        end
        if (cnt >= timeout_cycles) begin
            $display("ERROR: Timeout waiting for valid_o after %0d cycles!", timeout_cycles);
        end else begin
            $display("Output received after %0d cycles", cnt);
        end
    endtask
    
    // Task: Check output against expected
    task automatic check_output(
        input string test_name,
        input m31_t [WIDTH-1:0] expected
    );
        integer i;
        integer mismatch_count;
        integer all_match;
        
        all_match = 1;
        mismatch_count = 0;
        
        $display("Output:");
        for (i = 0; i < WIDTH; i = i + 1) begin
            $display("  [%0d]: 0x%08h", i, state_o[i]);
        end
        
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (state_o[i] !== expected[i]) begin
                all_match = 0;
                mismatch_count = mismatch_count + 1;
            end
        end
        
        if (all_match == 1) begin
            $display("%s PASSED", test_name);
        end else begin
            $display("%s FAILED (%0d mismatches)", test_name, mismatch_count);
            for (i = 0; i < WIDTH; i = i + 1) begin
                if (state_o[i] !== expected[i]) begin
                    $display("  [%0d]: Got 0x%08h, Expected 0x%08h", i, state_o[i], expected[i]);
                end
            end
        end
    endtask
    
    // Main test
    initial begin
        integer i;
        
        $display("=== Poseidon2 Iterative Module Testbench ===");
        $display("Configuration: WIDTH=%0d, FULL_HALF=%0d, PARTIAL=%0d",
                 WIDTH, N_FULL_ROUNDS_HALF, N_PARTIAL_ROUNDS);
        $display("Expected round latency: 19 cycles/round");
        $display("Expected total latency: ~%0d cycles", 22 * 19 + 4);
        
        // Reset
        rst_n = 0;
        valid_i = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            state_i[i] = 31'h0;
        end
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // Test Case 1: Sequential input (1, 2, 3, ..., 16)
        // =====================================================================
        $display("\n=== Test Case 1: Sequential Input ===");
        
        // Wait for ready
        while (!ready_o) @(posedge clk);
        
        state_i[0]  = 31'h00000001;
        state_i[1]  = 31'h00000002;
        state_i[2]  = 31'h00000003;
        state_i[3]  = 31'h00000004;
        state_i[4]  = 31'h00000005;
        state_i[5]  = 31'h00000006;
        state_i[6]  = 31'h00000007;
        state_i[7]  = 31'h00000008;
        state_i[8]  = 31'h00000009;
        state_i[9]  = 31'h0000000a;
        state_i[10] = 31'h0000000b;
        state_i[11] = 31'h0000000c;
        state_i[12] = 31'h0000000d;
        state_i[13] = 31'h0000000e;
        state_i[14] = 31'h0000000f;
        state_i[15] = 31'h00000010;
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        $display("Input:");
        for (i = 0; i < WIDTH; i = i + 1) begin
            $display("  [%0d]: 0x%08h", i, state_i[i]);
        end
        
        // Expected output (same as original testbench)
        expected_1[0]  = 31'h34ecac18;
        expected_1[1]  = 31'h41e09387;
        expected_1[2]  = 31'h62a4f1ff;
        expected_1[3]  = 31'h4fdc544d;
        expected_1[4]  = 31'h650902f6;
        expected_1[5]  = 31'h58219dea;
        expected_1[6]  = 31'h6227e044;
        expected_1[7]  = 31'h7f092d69;
        expected_1[8]  = 31'h00896716;
        expected_1[9]  = 31'h7e57d05a;
        expected_1[10] = 31'h65718fb0;
        expected_1[11] = 31'h0bb02216;
        expected_1[12] = 31'h437f68b6;
        expected_1[13] = 31'h551e058f;
        expected_1[14] = 31'h518affa5;
        expected_1[15] = 31'h60f6e959;
        
        wait_for_output(600);
        check_output("Test Case 1", expected_1);
        
        // =====================================================================
        // Test Case 2: Reference implementation test vector
        // =====================================================================
        $display("\n=== Test Case 2: Reference Implementation Test ===");
        
        // Wait for ready
        while (!ready_o) @(posedge clk);
        
        state_i[0]  = 31'h35564d4d;
        state_i[1]  = 31'h55b0dfe4;
        state_i[2]  = 31'h478fcda5;
        state_i[3]  = 31'h64bb8cd4;
        state_i[4]  = 31'h043d6042;
        state_i[5]  = 31'h6842c6a7;
        state_i[6]  = 31'h6665cdb7;
        state_i[7]  = 31'h07300aff;
        state_i[8]  = 31'h012dc216;
        state_i[9]  = 31'h0286b685;
        state_i[10] = 31'h6d300ca2;
        state_i[11] = 31'h2b343e20;
        state_i[12] = 31'h0a349cef;
        state_i[13] = 31'h4d705513;
        state_i[14] = 31'h0d8879f0;
        state_i[15] = 31'h6a51f0a1;
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        expected_2[0]  = 31'h43074f9a;
        expected_2[1]  = 31'h7ed0a25c;
        expected_2[2]  = 31'h6d5258f1;
        expected_2[3]  = 31'h47fbd9a9;
        expected_2[4]  = 31'h70b8d58d;
        expected_2[5]  = 31'h0ea85fe4;
        expected_2[6]  = 31'h3a7d1cdf;
        expected_2[7]  = 31'h256350ae;
        expected_2[8]  = 31'h5b7d1579;
        expected_2[9]  = 31'h5e39812c;
        expected_2[10] = 31'h34edc592;
        expected_2[11] = 31'h5af93122;
        expected_2[12] = 31'h20a6a2e9;
        expected_2[13] = 31'h3d504bfe;
        expected_2[14] = 31'h6b78ea87;
        expected_2[15] = 31'h1341ad2d;
        
        wait_for_output(600);
        check_output("Test Case 2", expected_2);
        
        // =====================================================================
        // Test Case 3: All zeros
        // =====================================================================
        $display("\n=== Test Case 3: All Zeros ===");
        
        while (!ready_o) @(posedge clk);
        
        for (i = 0; i < WIDTH; i = i + 1) begin
            state_i[i] = 31'h0;
        end
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        wait_for_output(600);
        
        $display("Output:");
        for (i = 0; i < WIDTH; i = i + 1) begin
            $display("  [%0d]: 0x%08h", i, state_o[i]);
        end
        
        // Check for X/Z
        for (i = 0; i < WIDTH; i = i + 1) begin
            if ($isunknown(state_o[i])) begin
                $display("FAILED: Unknown value at index %0d", i);
            end
        end
        $display("Test Case 3: X/Z check complete");
        
        // =====================================================================
        // Test Case 4: Maximum values (P_M31 - 1)
        // =====================================================================
        $display("\n=== Test Case 4: Maximum Values ===");
        
        while (!ready_o) @(posedge clk);
        
        for (i = 0; i < WIDTH; i = i + 1) begin
            state_i[i] = P_M31 - 1;
        end
        valid_i = 1;
        @(posedge clk);
        valid_i = 0;
        
        wait_for_output(600);
        
        $display("Output:");
        for (i = 0; i < WIDTH; i = i + 1) begin
            $display("  [%0d]: 0x%08h", i, state_o[i]);
        end
        
        for (i = 0; i < WIDTH; i = i + 1) begin
            if ($isunknown(state_o[i])) begin
                $display("FAILED: Unknown value at index %0d", i);
            end
        end
        $display("Test Case 4: X/Z check complete");
        
        $display("\n=== Testbench Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
