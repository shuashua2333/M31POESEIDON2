################################################################################
# M31 Poseidon2 (Iterative) -- Vivado Synthesis & Power Analysis Tcl Script
# Usage: source this in Vivado Tcl Console, or run in batch mode:
#   vivado -mode batch -source scripts/synth_and_power.tcl
################################################################################

# ==============================================================================
# User Configuration -- MODIFY THESE
# ==============================================================================
set PROJECT_NAME    "m31_poseidon2"
set TOP_MODULE      "m31_poseidon2_iterative"
set FPGA_PART       "xcku5p-ffvb676-2-e"
set RTL_DIR         "../rtl"
set XDC_FILE        "../constraints/m31_poseidon2.xdc"
set OUTPUT_DIR      "../output"

# ==============================================================================
# Step 0: Create Output Directory
# ==============================================================================
file mkdir $OUTPUT_DIR

# ==============================================================================
# Step 1: Create In-Memory Project
# ==============================================================================
create_project -in_memory -part $FPGA_PART

# ==============================================================================
# Step 2: Read RTL Sources (order matters for packages)
# ==============================================================================
read_verilog -sv [list \
    "$RTL_DIR/m31_pkg.sv"              \
    "$RTL_DIR/m31_constants_pkg.sv"    \
    "$RTL_DIR/m31_add.sv"             \
    "$RTL_DIR/m31_sub.sv"             \
    "$RTL_DIR/m31_mul.sv"             \
    "$RTL_DIR/m31_sqr.sv"             \
    "$RTL_DIR/m31_sbox.sv"            \
    "$RTL_DIR/m31_mds_4x4.sv"         \
    "$RTL_DIR/m31_mix_layer.sv"       \
    "$RTL_DIR/m31_op_full_round.sv"   \
    "$RTL_DIR/m31_op_partial_round.sv"\
    "$RTL_DIR/m31_poseidon2_iterative.sv" \
]

# ==============================================================================
# Step 3: Read Constraints
# ==============================================================================
read_xdc $XDC_FILE

# ==============================================================================
# Step 4: Synthesis
# ==============================================================================
puts "===== Starting Synthesis ====="

synth_design \
    -top $TOP_MODULE \
    -part $FPGA_PART \
    -flatten_hierarchy rebuilt \
    -retiming \
    -directive Default

# ==============================================================================
# Step 5: Post-Synthesis Reports
# ==============================================================================
puts "===== Generating Post-Synthesis Reports ====="

report_utilization -file "$OUTPUT_DIR/utilization_synth.rpt"
puts "Utilization report saved to $OUTPUT_DIR/utilization_synth.rpt"

report_timing_summary -file "$OUTPUT_DIR/timing_synth.rpt" \
    -max_paths 10 -delay_type max
puts "Timing report saved to $OUTPUT_DIR/timing_synth.rpt"

report_utilization -hierarchical \
    -hierarchical_depth 3 \
    -file "$OUTPUT_DIR/utilization_hier_synth.rpt"
puts "Hierarchical utilization saved to $OUTPUT_DIR/utilization_hier_synth.rpt"

# ==============================================================================
# Step 6: Power Analysis (Post-Synthesis Estimated)
# ==============================================================================
puts "===== Power Analysis ====="

set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
    [get_nets -hier -filter {TYPE == Signal}]

report_power -file "$OUTPUT_DIR/power_synth.rpt" \
    -advisory
puts "Power report saved to $OUTPUT_DIR/power_synth.rpt"

# ==============================================================================
# Step 7: Implementation (Recommended for Iterative Design)
# ==============================================================================
puts "===== Starting Implementation ====="

# Re-read constraints for implementation.
# In-memory projects do not persist XDC to the post-synthesis checkpoint
# (causes [Constraints 18-5210]). Re-reading ensures clock/IO/false-path
# constraints are available for place & route.
read_xdc $XDC_FILE

opt_design -directive ExploreWithRemap
place_design -directive ExtraTimingOpt
phys_opt_design -directive AggressiveExplore
route_design -directive AggressiveExplore

puts "===== Post-Implementation Reports ====="
report_utilization -file "$OUTPUT_DIR/utilization_impl.rpt"
report_timing_summary -file "$OUTPUT_DIR/timing_impl.rpt" -max_paths 10
report_power -file "$OUTPUT_DIR/power_impl.rpt" -advisory

# ==============================================================================
# Step 8: Summary Output
# ==============================================================================
puts ""
puts "============================================================"
puts "  Synthesis & Implementation Complete"
puts "  Target FPGA:  $FPGA_PART"
puts "  Top Module:   $TOP_MODULE"
puts "  Architecture: Folded/Iterative (22 rounds shared)"
puts "  Reports in:   $OUTPUT_DIR/"
puts "============================================================"
puts ""
puts "Key files to review:"
puts "  1. utilization_synth.rpt  -- DSP/FF/LUT usage"
puts "  2. power_synth.rpt       -- Estimated power breakdown"
puts "  3. timing_synth.rpt      -- Timing closure status"
puts "  4. utilization_impl.rpt  -- Post-implementation utilization"
puts "  5. timing_impl.rpt       -- Post-implementation timing"
puts "  6. power_impl.rpt        -- Post-implementation power"
puts ""
puts "Expected improvements:"
puts "  - DSP usage: ~200 (was 1824)"
puts "  - WNS: positive (was -30.113 ns)"
puts "  - Power: <3W (was 10.787 W)"
puts "============================================================"
