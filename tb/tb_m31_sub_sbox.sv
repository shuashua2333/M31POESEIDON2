`timescale 1ns/1ps

module tb_m31_sub_sbox ();

    // Import M31 Package
    import m31_pkg::*;

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    
    // Subtraction Signals
    m31_t        sub_a_i;
    m31_t        sub_b_i;
    m31_t        sub_res_o;

    // S-Box Signals
    m31_t        sbox_in_i;
    m31_t        sbox_out_o;

    // -------------------------------------------------------------------------
    // Clock & Reset Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    initial begin
        rst_n = 0;
        #50;
        rst_n = 1;
    end

    // -------------------------------------------------------------------------
    // Device Under Test (DUT) Instantiation
    // -------------------------------------------------------------------------
    
    // Subtraction DUT
    m31_sub u_sub (
        .clk    (clk),
        .rst_n  (rst_n),
        .a_i    (sub_a_i),
        .b_i    (sub_b_i),
        .res_o  (sub_res_o)
    );

    // S-Box DUT
    m31_sbox u_sbox (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_i   (sbox_in_i),
        .out_o  (sbox_out_o)
    );

    // -------------------------------------------------------------------------
    // Verification Tasks
    // -------------------------------------------------------------------------
    int errors_sub = 0;
    int errors_sbox = 0;

    task check_sub(input m31_t a, input m31_t b, input m31_t expected);
        // Drive inputs
        @(posedge clk);
        sub_a_i <= a;
        sub_b_i <= b;
        
        // Wait for combinational logic propagation
        // m31_sub is purely combinational (always_comb)
        #1; 
        
        if (sub_res_o !== expected) begin
            $error("[SUB FAIL] %x - %x = %x (Expected %x)", a, b, sub_res_o, expected);
            errors_sub++;
        end else begin
            // $display("[SUB PASS] %x - %x = %x", a, b, sub_res_o);
        end
    endtask

    task check_sbox(input m31_t val, input m31_t expected);
        // Drive inputs
        @(posedge clk);
        sbox_in_i <= val;
        
        // S-Box has latency.
        // x^2 (4) + x^4 (4) + x^5 (4) = 12 cycles.
        // Wait 12 cycles.
        repeat(12) @(posedge clk);
        #1;
        
        if (sbox_out_o !== expected) begin
            $error("[SBOX FAIL] Sbox(%x) = %x (Expected %x)", val, sbox_out_o, expected);
            errors_sbox++;
        end else begin
            // $display("[SBOX PASS] Sbox(%x) = %x", val, sbox_out_o);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Process
    // -------------------------------------------------------------------------
    initial begin
        // Initialize inputs
        sub_a_i = 0;
        sub_b_i = 0;
        sbox_in_i = 0;
        
        // Wait for reset
        @(posedge rst_n);
        @(posedge clk);
        
        $display("---------------------------------------------------");
        $display("Starting M31 Sub & Sbox Verification");
        $display("---------------------------------------------------");

        // ----------------------------------------------------------------
        // RUST GENERATED GOLDEN VECTORS
        // ----------------------------------------------------------------

        $display("\n--- Subtraction Vectors ---");
        check_sub(31'h0, 31'h0, 31'h0);
        check_sub(31'h1, 31'h0, 31'h1);
        check_sub(31'h1, 31'h1, 31'h0);
        check_sub(31'h0, 31'h1, 31'h7ffffffe);
        check_sub(31'h64, 31'h32, 31'h32);
        check_sub(31'h32, 31'h64, 31'h7fffffcd);
        check_sub(31'h7ffffffe, 31'h0, 31'h7ffffffe);
        check_sub(31'h0, 31'h7ffffffe, 31'h1);
        check_sub(31'h7ffffffe, 31'h7ffffffe, 31'h0);
        check_sub(31'h2a5abbb6, 31'h6f527c1c, 31'h3b083f99);
        check_sub(31'h63b5c67f, 31'hed1ea3, 31'h62c8a7dc);
        check_sub(31'h3f40ee2f, 31'h4b10d13d, 31'h74301cf1);
        check_sub(31'h7cd48a24, 31'h377604dc, 31'h455e8548);
        check_sub(31'h5b342196, 31'h2355bb8d, 31'h37de6609);

        // --- S-Box Vectors (x^5) ---
        $display("\n--- S-Box Vectors (x^5) ---");
        // Pipeline flush wait for safety or just sequential calls
        check_sbox(31'h0, 31'h0);
        check_sbox(31'h1, 31'h1);
        check_sbox(31'h2, 31'h20);
        check_sbox(31'h3, 31'hf3);
        check_sbox(31'h7ffffffe, 31'h7ffffffe);
        check_sbox(31'h5f5dc700, 31'h37a12460);
        check_sbox(31'h6c8ed567, 31'h2e420e81);
        check_sbox(31'hf7cc7cc, 31'h3b48856e);
        check_sbox(31'h4b99671d, 31'h74a3d2a5);
        check_sbox(31'h77c9c7cf, 31'h6a725476);

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
        $display("---------------------------------------------------");
        if (errors_sub == 0 && errors_sbox == 0) begin
            $display("VERIFICATION SUCCESS: All tests passed!");
        end else begin
            $display("VERIFICATION FAILED: %d sub errors, %d sbox errors.", errors_sub, errors_sbox);
        end
        $display("---------------------------------------------------");
        
        $finish;
    end

endmodule
