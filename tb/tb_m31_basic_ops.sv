`timescale 1ns/1ps

module tb_m31_basic_ops ();

    // Import M31 Package
    import m31_pkg::*;

    // -------------------------------------------------------------------------
    // Signal Declarations
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_n;
    
    // Inputs
    m31_t        a_i;
    m31_t        b_i;
    
    // Outputs
    m31_t        add_res_o;
    m31_t        mul_res_o;

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
    m31_add u_add (
        .clk    (clk),
        .rst_n  (rst_n),
        .a_i    (a_i),
        .b_i    (b_i),
        .res_o  (add_res_o)
    );

    m31_mul u_mul (
        .clk    (clk),
        .rst_n  (rst_n),
        .a_i    (a_i),
        .b_i    (b_i),
        .res_o  (mul_res_o)
    );

    // -------------------------------------------------------------------------
    // Reference Models (Golden Model)
    // -------------------------------------------------------------------------
    function m31_t golden_add(input m31_t a, input m31_t b);
        logic [31:0] sum;
        sum = {1'b0, a} + {1'b0, b};
        // Modulo 2^31 - 1
        // If sum >= P, sum = sum - P. Since P = 2^31-1, this is equiv to end-around carry
        // But for golden model, let's stick to simple % or manual check
        if (sum >= 32'h7FFFFFFF) begin
            // sum = sum - P
            // sum - (2^31 - 1) = sum - 2^31 + 1
            // But easier: sum_folded = sum[30:0] + sum[31]
             golden_add = (sum[30:0] + sum[31]);
             if (golden_add == 31'h7FFFFFFF) golden_add = 0; // Canonical
        end else begin
            golden_add = sum[30:0];
        end
    endfunction

    // Helper for multiplication checking
    // Since hardware has 4 cycle latency, we need to compare against delayed expected value
    // or just check "eventually" in a directed test. 
    // For simplicity in this TB, we will use directed tests and wait for result.

    // -------------------------------------------------------------------------
    // Test Process
    // -------------------------------------------------------------------------
    int errors = 0;

    task check_add(input m31_t a, input m31_t b, input string name);
        m31_t expected;
        expected = golden_add(a, b);
        
        // Drive inputs
        @(posedge clk);
        a_i <= a;
        b_i <= b;
        
        // Wait for result (Add is usually combinational or 1 cycle depending on impl, 
        // looking at m31_add.sv it is combinational? No, always_comb. So instantaneous.)
        // But let's wait a tiny bit for stability or next edge if registered?
        // m31_add.sv is pure combinational logic inside "always_comb".
        #1; 
        
        if (add_res_o !== expected) begin
            $error("[ADD FAIL] %s: %d + %d = %d (Expected %d)", name, a, b, add_res_o, expected);
            errors++;
        end else begin
            $display("[ADD PASS] %s: %d + %d = %d", name, a, b, add_res_o);
        end
    endtask

    task check_mul(input m31_t a, input m31_t b, input string name);
        longint full_prod; // Use 64-bit for calculation
        m31_t expected;
        
        full_prod = {33'd0, a} * {33'd0, b}; // Force 64-bit mult
        expected = full_prod % 2147483647; // 2^31 - 1
        
        // Drive inputs
        @(posedge clk);
        a_i <= a;
        b_i <= b;
        
        // MUL has 4 cycle latency
        repeat(4) @(posedge clk);
        #1; // Wait for propagation/assignments
        
        if (mul_res_o !== expected) begin
            $error("[MUL FAIL] %s: %d * %d = %d (Expected %d)", name, a, b, mul_res_o, expected);
            errors++;
        end else begin
            $display("[MUL PASS] %s: %d * %d = %d", name, a, b, mul_res_o);
        end
    endtask

    task check_vector(input m31_t a, input m31_t b, input m31_t exp_sum, input m31_t exp_prod);
        // Drive inputs
        @(posedge clk);
        a_i <= a;
        b_i <= b;

        // Check ADD (combinational/immediate)
        #1; 
        if (add_res_o !== exp_sum) begin
            $error("[ADD FAIL] Vector A=%x B=%x: Sum=%x (Expected %x)", a, b, add_res_o, exp_sum);
            errors++;
        end else begin
            // $display("[ADD PASS] Vector A=%x B=%x", a, b);
        end

        // Check MUL (latency 4)
        // We already waited 1 cycle (posedge clk above), but MUL output is registered with latency 4.
        // Wait 4 cycles for MUL.
        // Since ADD is combinational, it was valid immediately.
        // We need to keep a_i/b_i stable or just wait 4 cycles.
        // The previous task (check_mul) waits 4 cycles.
        
        repeat(4) @(posedge clk);
        #1;
        if (mul_res_o !== exp_prod) begin
            $error("[MUL FAIL] Vector A=%x B=%x: Prod=%x (Expected %x)", a, b, mul_res_o, exp_prod);
            errors++;
        end else begin
            // $display("[MUL PASS] Vector A=%x B=%x", a, b);
        end
        
        $display("[VECTOR PASS] A=%x B=%x OK", a, b);
    endtask

    initial begin
        // Initialize
        a_i = 0;
        b_i = 0;
        
        // Wait for Reset
        @(posedge rst_n);
        @(posedge clk);
        $display("---------------------------------------------------");
        $display("Starting M31 Basic Ops Verification");
        $display("---------------------------------------------------");

        // ------------------------------------------------------------
        // ADDITION TESTS
        // ------------------------------------------------------------
        $display("\n--- Testing Addition ---");
        check_add(0, 0, "Zero + Zero");
        check_add(1, 1, "1 + 1");
        check_add(100, 200, "Small Numbers");
        check_add(P_M31 - 1, 1, "Boundary: (P-1) + 1 -> 0");
        check_add(P_M31 - 5, 10, "Wrap Around");
        
        // Randomized Addition
        repeat(10) begin
            m31_t ra, rb;
            ra = $urandom_range(0, P_M31-1); // random 0 to P-1
            rb = $urandom_range(0, P_M31-1);
            check_add(ra, rb, "Random Add");
        end

        // ------------------------------------------------------------
        // MULTIPLICATION TESTS
        // ------------------------------------------------------------
        $display("\n--- Testing Multiplication ---");
        // Pipeline flush wait
        @(posedge clk);
        
        check_mul(0, 500, "Zero * N");
        check_mul(1, 12345, "One * N");
        check_mul(2, 4, "2 * 4");
        check_mul(10, 10, "10 * 10");
        check_mul(P_M31 - 1, 1, "(P-1) * 1"); // -1 * 1 = -1 = P-1
        check_mul(P_M31 - 1, P_M31 - 1, "(P-1) * (P-1)"); // -1 * -1 = 1
        
        // Randomized Multiplication
        repeat(10) begin
            m31_t ra, rb;
            ra = $urandom_range(0, P_M31-1);
            rb = $urandom_range(0, P_M31-1);
            check_mul(ra, rb, "Random Mul");
        end

        // ------------------------------------------------------------
        // RUST GENERATED GOLDEN VECTORS
        // ------------------------------------------------------------
        $display("\n--- Testing Rust Golden Vectors ---");
        // A=00000000, B=00000000 -> Sum=00000000, Prod=00000000
        check_vector(31'h0, 31'h0, 31'h0, 31'h0);
        // A=00000001, B=00000001 -> Sum=00000002, Prod=00000001
        check_vector(31'h1, 31'h1, 31'h2, 31'h1);
        // A=7ffffffe, B=00000001 -> Sum=00000000, Prod=7ffffffe
        check_vector(31'h7ffffffe, 31'h1, 31'h0, 31'h7ffffffe);
        // A=7ffffffe, B=7ffffffe -> Sum=7ffffffd, Prod=00000001
        check_vector(31'h7ffffffe, 31'h7ffffffe, 31'h7ffffffd, 31'h1);
        // A=2e413a1f, B=16332d59 -> Sum=44746778, Prod=52175c24
        check_vector(31'h2e413a1f, 31'h16332d59, 31'h44746778, 31'h52175c24);
        // A=01eed090, B=1b66d324 -> Sum=1d55a3b4, Prod=6545f1bc
        check_vector(31'h1eed090, 31'h1b66d324, 31'h1d55a3b4, 31'h6545f1bc);
        // A=6ec7a966, B=2cb0c277 -> Sum=1b786bde, Prod=71fca77b
        check_vector(31'h6ec7a966, 31'h2cb0c277, 31'h1b786bde, 31'h71fca77b);
        // A=0678baf5, B=41dce872 -> Sum=4855a367, Prod=2e11c34c
        check_vector(31'h678baf5, 31'h41dce872, 31'h4855a367, 31'h2e11c34c);
        // A=24c1a869, B=12b0899e -> Sum=37723207, Prod=02340f49
        check_vector(31'h24c1a869, 31'h12b0899e, 31'h37723207, 31'h2340f49);
        // A=44d04ecf, B=236d8852 -> Sum=683dd721, Prod=22c60e87
        check_vector(31'h44d04ecf, 31'h236d8852, 31'h683dd721, 31'h22c60e87);
        // A=5ebb8073, B=72641f2f -> Sum=511f9fa3, Prod=508f9a14
        check_vector(31'h5ebb8073, 31'h72641f2f, 31'h511f9fa3, 31'h508f9a14);
        // A=4c9b1162, B=67112086 -> Sum=33ac31e9, Prod=4e886158
        check_vector(31'h4c9b1162, 31'h67112086, 31'h33ac31e9, 31'h4e886158);
        // A=7b1ed0e3, B=61ae4bec -> Sum=5ccd1cd0, Prod=62da137b
        check_vector(31'h7b1ed0e3, 31'h61ae4bec, 31'h5ccd1cd0, 31'h62da137b);
        // A=488de342, B=17f7ee0d -> Sum=6085d14f, Prod=58bfedeb
        check_vector(31'h488de342, 31'h17f7ee0d, 31'h6085d14f, 31'h58bfedeb);

        // ------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------
        $display("---------------------------------------------------");
        if (errors == 0) begin
            $display("VERIFICATION SUCCESS: All tests passed!");
        end else begin
            $display("VERIFICATION FAILED: %d errors found.", errors);
        end
        $display("---------------------------------------------------");
        
        $stop;
    end

endmodule
