################################################################################
# M31 Poseidon2 -- Vivado Synthesis & Power Analysis Tcl Script
# Usage: source this in Vivado Tcl Console, or run in batch mode:
#   vivado -mode batch -source scripts/synth_and_power.tcl
################################################################################

# ==============================================================================
# User Configuration -- MODIFY THESE
# ==============================================================================
set PROJECT_NAME    "m31_poseidon2"
set TOP_MODULE      "m31_poseidon2_top"
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
    "$RTL_DIR/m31_poseidon2_top.sv"   \
]

# ==============================================================================
# Step 3: Read Constraints
# ==============================================================================
read_xdc $XDC_FILE

# ==============================================================================
# Step 4: Synthesis
# ==============================================================================
puts "===== Starting Synthesis ====="

# Synthesis settings for power optimization
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value {-directive AreaOptimized_high} -objects [current_run -synthesis]

synth_design \
    -top $TOP_MODULE \
    -part $FPGA_PART \
    -flatten_hierarchy rebuilt \
    -retiming \
    -directive AreaOptimized_high

# ==============================================================================
# Step 5: Post-Synthesis Reports
# ==============================================================================
puts "===== Generating Post-Synthesis Reports ====="

# Utilization Report (critical: check DSP, FF, LUT usage)
report_utilization -file "$OUTPUT_DIR/utilization_synth.rpt"
puts "Utilization report saved to $OUTPUT_DIR/utilization_synth.rpt"

# Timing Summary
report_timing_summary -file "$OUTPUT_DIR/timing_synth.rpt" \
    -max_paths 10 -delay_type max
puts "Timing report saved to $OUTPUT_DIR/timing_synth.rpt"

# DSP Usage Detail
report_utilization -hierarchical \
    -hierarchical_depth 3 \
    -file "$OUTPUT_DIR/utilization_hier_synth.rpt"
puts "Hierarchical utilization saved to $OUTPUT_DIR/utilization_hier_synth.rpt"

# ==============================================================================
# Step 6: Power Analysis (Post-Synthesis Estimated)
# ==============================================================================
puts "===== Power Analysis ====="

# Set realistic switching activity for data paths
set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
    [get_nets -hier -filter {TYPE == Signal}]

# Generate power report
report_power -file "$OUTPUT_DIR/power_synth.rpt" \
    -advisory
puts "Power report saved to $OUTPUT_DIR/power_synth.rpt"

# ==============================================================================
# Step 7: (Optional) Implementation for Accurate Power
# ==============================================================================
# Uncomment the following for post-implementation power analysis.
# This is more accurate but takes longer.

# puts "===== Starting Implementation ====="
# opt_design -directive ExploreWithRemap
# place_design -directive ExtraTimingOpt
# phys_opt_design -directive AggressiveExplore
# route_design -directive AggressiveExplore
#
# puts "===== Post-Implementation Reports ====="
# report_utilization -file "$OUTPUT_DIR/utilization_impl.rpt"
# report_timing_summary -file "$OUTPUT_DIR/timing_impl.rpt" -max_paths 10
# report_power -file "$OUTPUT_DIR/power_impl.rpt" -advisory
#
# # Thermal analysis
# report_design_analysis -timing -file "$OUTPUT_DIR/design_analysis.rpt"

# ==============================================================================
# Step 8: Summary Output
# ==============================================================================
puts ""
puts "============================================================"
puts "  Synthesis Complete"
puts "  Target FPGA:  $FPGA_PART"
puts "  Top Module:   $TOP_MODULE"
puts "  Reports in:   $OUTPUT_DIR/"
puts "============================================================"
puts ""
puts "Key files to review:"
puts "  1. utilization_synth.rpt  -- DSP/FF/LUT usage"
puts "  2. power_synth.rpt       -- Estimated power breakdown"
puts "  3. timing_synth.rpt      -- Timing closure status"
puts ""
puts "Next steps:"
puts "  - Check if DSPs are properly inferred (expect ~1700)"
puts "  - Check dynamic power breakdown (clock vs signal vs DSP)"
puts "  - Run implementation (uncomment Step 7) for accurate power"
puts "============================================================"
