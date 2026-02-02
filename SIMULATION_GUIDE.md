# Quick Simulation Guide - Poseidon2 Top Module

## Files Overview

### Modified Files
- ✅ `rtl/m31_poseidon2_top.sv` - Fixed constant connection syntax (lines 88, 118)

### New Files Created
1. **Rust Test Vector Generator**
   - `mersenne-31-workspace/examples/gen_poseidon2_top_vectors.rs`
   - Output: `mersenne-31-workspace/poseidon2_top_vectors.txt`

2. **SystemVerilog Testbench**
   - `tb/tb_m31_poseidon2_top.sv`

3. **Documentation**
   - `VERIFICATION_REPORT_TOP.md` (English)
   - `验证总结_顶层模块.md` (Chinese)

## Running in Vivado Simulator

### Step 1: Add Testbench to Project
```tcl
# In Vivado TCL Console
add_files -fileset sim_1 {G:/desktop/M31POESEIDON2/tb/tb_m31_poseidon2_top.sv}
set_property top tb_m31_poseidon2_top [get_filesets sim_1]
update_compile_order -fileset sim_1
```

### Step 2: Run Simulation
```tcl
# Launch simulation
launch_simulation

# Or run behavioral simulation
launch_simulation -mode behavioral

# Run for sufficient time (all tests complete in ~3000ns)
run 5000ns
```

### Step 3: Check Results
Look for these messages in the TCL Console:
```
=== Poseidon2 Top Module Testbench ===
Configuration: WIDTH=16, N_FULL_ROUNDS_HALF=4, N_PARTIAL_ROUNDS=14

=== Test Case 1: Sequential Input ===
✓ Test Case 1 PASSED

=== Test Case 2: Reference Implementation Test ===
✓ Test Case 2 PASSED

=== Test Case 3: All Zeros ===
(No expected value - just checking for no X/Z)

=== Test Case 4: Maximum Values ===
(No expected value - just checking for no X/Z)

=== Testbench Complete ===
```

## Expected Behavior

### Timing
- **Pipeline Latency**: 23 clock cycles
- **Clock Period**: 10ns (100MHz)
- **Each test waits**: 25 cycles to ensure pipeline is flushed

### Test Cases

#### Test 1: Sequential Input [1,2,3,...,16]
**Expected Output (Hex)**:
```
3b3afc36 0dc611de 17546837 06df3d57
1bf3a1b1 47c56c39 7c31c4f3 1885faf7
393ce878 293c33d7 23196f8c 2ec056ca
6c3709df 71e8b1ab 57259c5f 5d928d7f
```

#### Test 2: Plonky3 Reference Test
**Input (Hex)**:
```
35564d4d 55b0dfe4 478fcda5 64bb8cd4
043d6042 6842c6a7 6665cdb7 07300aff
012dc216 0286b685 6d300ca2 2b343e20
0a349cef 4d705513 0d8879f0 6a51f0a1
```

**Expected Output (Hex)**:
```
43074f9a 7ed0a25c 6d5258f1 47fbd9a9
70b8d58d 0ea85fe4 3a7d1cdf 256350ae
5b7d1579 5e39812c 34edc592 5af93122
20a6a2e9 3d504bfe 6b78ea87 1341ad2d
```

## Troubleshooting

### If Tests Fail

1. **Check for X/Z values**
   - Look for "Unknown value" messages
   - Indicates uninitialized or incorrect logic

2. **Verify pipeline depth**
   - Output should appear exactly 23 cycles after input
   - Check if waiting long enough (25 cycles in testbench)

3. **Check constant loading**
   - Ensure `m31_constants_pkg.sv` is compiled
   - Verify import statements work correctly

4. **Compare intermediate values**
   - Use waveform viewer to check intermediate states
   - Compare with values in `poseidon2_top_vectors.txt`

### Common Issues

**Issue**: Testbench not found
- **Solution**: Make sure testbench is added to sim_1 fileset

**Issue**: Package not found
- **Solution**: Ensure compilation order is correct:
  1. `m31_pkg.sv`
  2. `m31_constants_pkg.sv`
  3. All RTL modules
  4. Testbench

**Issue**: Simulation hangs
- **Solution**: Check for combinational loops or missing clock

## Waveform Signals to Monitor

### Top Level
- `clk` - Clock signal
- `rst_n` - Reset (active low)
- `state_i[15:0]` - Input state
- `state_o[15:0]` - Output state

### Internal Signals (for debugging)
- `pre_mds_out[15:0]` - After initial MDS light
- `chain_initial[0:4]` - Initial full rounds chain
- `chain_partial[0:14]` - Partial rounds chain
- `chain_terminal[0:4]` - Terminal full rounds chain

## Success Criteria

✅ All test cases show "PASSED" message
✅ No X/Z values in outputs
✅ Output matches expected values exactly
✅ Pipeline latency is 23 cycles
✅ No synthesis warnings about constants

## Next Steps After Simulation

1. **Synthesis**: Run synthesis to check resource usage
2. **Timing Analysis**: Verify timing constraints are met
3. **Implementation**: Place and route for target FPGA
4. **Hardware Testing**: Test on actual FPGA if available

## Reference Files

- **Rust Reference**: `Plonky3-main/mersenne-31/src/poseidon2.rs`
- **Test Vectors**: `mersenne-31-workspace/poseidon2_top_vectors.txt`
- **Verification Report**: `VERIFICATION_REPORT_TOP.md`
- **中文总结**: `验证总结_顶层模块.md`
