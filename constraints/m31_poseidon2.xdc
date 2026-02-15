################################################################################
# M31 Poseidon2 -- Vivado XDC Constraints
# Target FPGA:  Xilinx Kintex UltraScale+  XCKU5P-2FFVB676E
# Design:       m31_poseidon2_top (fully-unrolled pipeline, WIDTH=16)
# Author:       auto-generated
# Date:         2026-02-11
################################################################################

# ==============================================================================
#  1. Clock Definition
# ==============================================================================
# Primary clock -- adjust period to match your board oscillator / PLL output.
# 200 MHz  =>  5.000 ns   (recommended starting point for UltraScale+)
# 100 MHz  =>  10.000 ns  (conservative, easier timing closure)
#
# If using a board oscillator on a specific pin, uncomment and set the pin:
#   set_property PACKAGE_PIN <pin> [get_ports clk]
#   set_property IOSTANDARD LVCMOS33  [get_ports clk]

create_clock -period 5.000 -name sys_clk [get_ports clk]

# Clock uncertainty (jitter + setup margin), default 0.1 ns for on-chip PLL
set_clock_uncertainty 0.100 [get_clocks sys_clk]

# ==============================================================================
#  2. Input / Output Delay Constraints
# ==============================================================================
# These constrain the timing of data arriving at / leaving the FPGA pins.
# Adjust values based on your PCB / interface timing budget.
# General rule: set to ~30-40% of clock period for moderate constraint.

set_input_delay  -clock sys_clk 2.000 [get_ports {state_i[*]}]
set_input_delay  -clock sys_clk 0.500 [get_ports rst_n]

set_output_delay -clock sys_clk 2.000 [get_ports {state_o[*]}]

# ==============================================================================
#  3. I/O Standards  (uncomment & adjust for your board)
# ==============================================================================
# set_property IOSTANDARD LVCMOS18  [get_ports clk]
# set_property IOSTANDARD LVCMOS18  [get_ports rst_n]
# set_property IOSTANDARD LVCMOS18  [get_ports {state_i[*]}]
# set_property IOSTANDARD LVCMOS18  [get_ports {state_o[*]}]

# ==============================================================================
#  4. Reset Network
# ==============================================================================
# Mark rst_n as asynchronous to the clock domain (if driven by external button)
# to prevent the tool from trying to meet setup/hold on it.
set_false_path -from [get_ports rst_n]

# ==============================================================================
#  5. Synthesis Optimization Attributes
# ==============================================================================

# --- 5a. DSP Inference ---
# Force multiplications to map to DSP48E2 slices (critical for M31 mul/sqr).
# Without this, the tool may use LUT-based multipliers => power explosion.
set_property USE_DSP48 YES [get_cells -hier -filter {REF_NAME =~ *m31_mul*}]
set_property USE_DSP48 YES [get_cells -hier -filter {REF_NAME =~ *m31_sqr*}]

# --- 5b. SRL Inference for delay lines ---
# Encourage Xilinx tools to use SRL16E / SRLC32E for shift-register chains
# instead of discrete flip-flops.  (Requires the SV code to NOT have reset
# on the delay line -- the current m31_sbox and m31_op_partial_round modules
# should ideally have reset removed from delay lines for this to take effect.)
set_property SHREG_EXTRACT YES [get_cells -hier -filter {NAME =~ *delay_line*}]
set_property SHREG_EXTRACT YES [get_cells -hier -filter {NAME =~ *delay_regs*}]

# --- 5c. Register Balancing / Retiming ---
# Allow the synthesis tool to move registers across combinational logic for
# better timing. This is especially beneficial for DSP pipeline registers.
# (Vivado 2018+)
# set_property REGISTER_BALANCING YES [get_cells -hier]

# ==============================================================================
#  6. Power Optimization
# ==============================================================================

# --- 6a. Switching Activity ---
# Provide realistic switching activity estimates for power analysis.
# Default toggle rate is 12.5% which is often pessimistic.
# Poseidon2 data paths toggle ~50% on average (crypto hash), so set
# a moderate value for more accurate power estimation.
#
# NOTE: These per-net constraints are DISABLED because they match too
# many nets (up to 2.3M), causing critical warnings and extreme slowdown.
# The global switching activity is already set in synth_and_power.tcl.
#
# set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
#     [get_nets -hier -filter {NAME =~ *state*}]
#
# set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
#     [get_nets -hier -filter {NAME =~ *sbox*}]
#
# set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
#     [get_nets -hier -filter {NAME =~ *prod*}]
#
# set_switching_activity -toggle_rate 25.0 -static_probability 0.5 \
#     [get_nets -hier -filter {NAME =~ *sum*}]

# --- 6b. Clock gating (Vivado will insert automatically if beneficial) ---
# NOTE: POWER_OPT_BRAM_CDC property does not exist on this device/Vivado version.
# set_property POWER_OPT_BRAM_CDC   NO   [current_design]
# Uncomment to enable aggressive clock gating during implementation:
# set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# ==============================================================================
#  7. Placement / Floorplanning Hints  (optional)
# ==============================================================================
# If your design is large, consider constraining major blocks to SLR regions
# on multi-SLR devices to reduce inter-SLR crossing penalties.
# Example for XCKU5P (single SLR -- no SLR constraint needed).

# For multi-SLR devices (e.g., XCVU9P), you might add:
# create_pblock pblock_initial_rounds
# add_cells_to_pblock [get_pblocks pblock_initial_rounds] \
#     [get_cells -hier -filter {NAME =~ *gen_r_init*}]
# resize_pblock pblock_initial_rounds -add {SLR0}

# ==============================================================================
#  8. Timing Exceptions
# ==============================================================================
# Multi-cycle paths: none currently needed (fully pipelined design).
# If you later add a valid/ready handshake, set multicycle paths accordingly:
# set_multicycle_path 2 -setup -from [get_pins ...] -to [get_pins ...]
# set_multicycle_path 1 -hold  -from [get_pins ...] -to [get_pins ...]

# ==============================================================================
#  9. Implementation Strategy
# ==============================================================================
# Use Performance_ExplorePostRoutePhysOpt for best power/timing trade-off:
# set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
#
# Or use Power_DefaultOpt for power-focused implementation:
# set_property strategy Power_DefaultOpt [get_runs impl_1]

# ==============================================================================
# 10. Debug  (uncomment only when needed, remove for final builds)
# ==============================================================================
# set_property MARK_DEBUG true [get_nets {state_o[*]}]
# set_property MARK_DEBUG true [get_nets {state_i[*]}]
