`timescale 1ns/1ps
import m31_pkg::*;

module tb_m31_mds_mix;

    // --- Signals ---
    m31_t [3:0] mds_in;
    m31_t [3:0] mds_out;
    m31_t [3:0] mds_expected;
    
    m31_t [15:0] mix_in;
    m31_t [15:0] mix_out;
    m31_t [15:0] mix_expected;
    
    // --- DUT Instantiation ---
    m31_mds_4x4 u_mds (
        .state_i(mds_in),
        .state_o(mds_out)
    );
    
    m31_mix_layer #(.WIDTH(16)) u_mix (
        .state_i(mix_in),
        .state_o(mix_out)
    );
    
    // --- Test Logic ---
    initial begin
        $display("Starting m31_mds_4x4 and m31_mix_layer Verification");
        
        // ---------------------------------------------------------
        // Test 1: MDS 4x4
        // ---------------------------------------------------------
        // ---------------------------------------------------------
        // Test 1: MDS 4x4
        // ---------------------------------------------------------
        // Generated Vectors
        mds_in[0] = 31'd572990626;
        mds_in[1] = 31'd114063204;
        mds_in[2] = 31'd1068323197;
        mds_in[3] = 31'd183503380;
        
        mds_expected[0] = 31'd592513794;
        mds_expected[1] = 31'd2042106358;
        mds_expected[2] = 31'd1226726717;
        mds_expected[3] = 31'd1120881392;
        
        #10;
        if (mds_out !== mds_expected) begin
            $display("[FAIL] MDS 4x4 Mismatch!");
            for (int i=0; i<4; i++) $display("  [%0d] Exp: %d, Got: %d", i, mds_expected[i], mds_out[i]);
        end else begin
            $display("[PASS] MDS 4x4");
        end
        
        // ---------------------------------------------------------
        // Test 2: Mix Layer (Width 16)
        // ---------------------------------------------------------
        // Generated Vectors
        mix_in[0] = 31'd1582380242;
        mix_in[1] = 31'd586113138;
        mix_in[2] = 31'd2104897715;
        mix_in[3] = 31'd1743334776;
        mix_in[4] = 31'd2014420971;
        mix_in[5] = 31'd147501279;
        mix_in[6] = 31'd504332713;
        mix_in[7] = 31'd1782226083;
        mix_in[8] = 31'd1493727483;
        mix_in[9] = 31'd1019730153;
        mix_in[10] = 31'd797882167;
        mix_in[11] = 31'd1500024220;
        mix_in[12] = 31'd555516767;
        mix_in[13] = 31'd563838535;
        mix_in[14] = 31'd2059024926;
        mix_in[15] = 31'd13967647;

        mix_expected[0] = 31'd785974764;
        mix_expected[1] = 31'd755812596;
        mix_expected[2] = 31'd1128584295;
        mix_expected[3] = 31'd340436561;
        mix_expected[4] = 31'd1218015493;
        mix_expected[5] = 31'd317200737;
        mix_expected[6] = 31'd1675502940;
        mix_expected[7] = 31'd379327868;
        mix_expected[8] = 31'd697322005;
        mix_expected[9] = 31'd1189429611;
        mix_expected[10] = 31'd1969052394;
        mix_expected[11] = 31'd97126005;
        mix_expected[12] = 31'd1906594936;
        mix_expected[13] = 31'd733537993;
        mix_expected[14] = 31'd1082711506;
        mix_expected[15] = 31'd758553079;

        
        // Wait for vectors to be applied (if assignments were distinct)
        #10;
        
        if (mix_out !== mix_expected) begin
            $display("[FAIL] Mix Layer Mismatch!");
            for (int i=0; i<16; i++) begin
                if (mix_out[i] !== mix_expected[i])
                    $display("  [%0d] Exp: %d, Got: %d", i, mix_expected[i], mix_out[i]);
            end
        end else begin
            $display("[PASS] Mix Layer");
        end
        
        $finish;
    end

endmodule
