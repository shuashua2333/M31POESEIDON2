################################################################################
# M31 Poseidon2 (Iterative) -- Vivado XDC Constraints
# Target FPGA:  Xilinx Kintex UltraScale+  XCKU5P-2FFVB676E
# Design:       m31_poseidon2_iterative (folded, WIDTH=16)
# Date:         2026-02-15
################################################################################

# ==============================================================================
#  1. Clock Definition
# ==============================================================================
# 100 MHz => 10.000 ns (realistic for pipelined iterative architecture)
create_clock -period 10.000 -name sys_clk [get_ports clk]

# Clock uncertainty
set_clock_uncertainty 0.100 [get_clocks sys_clk]

# ==============================================================================
#  2. Input / Output Delay Constraints
# ==============================================================================
set_input_delay  -clock sys_clk 0.500 [get_ports {state_i[*]}]
set_input_delay  -clock sys_clk 0.500 [get_ports rst_n]
set_input_delay  -clock sys_clk 0.500 [get_ports valid_i]

set_output_delay -clock sys_clk 0.500 [get_ports {state_o[*]}]
set_output_delay -clock sys_clk 1.000 [get_ports valid_o]
set_output_delay -clock sys_clk 1.000 [get_ports ready_o]

# ==============================================================================
#  3. Reset Network
# ==============================================================================
set_false_path -from [get_ports rst_n]

# ==============================================================================
#  4. Synthesis Optimization Attributes
# ==============================================================================

# Force multiplications to DSP48E2
set_property USE_DSP48 YES [get_cells -hier -filter {REF_NAME =~ *m31_mul*}]
set_property USE_DSP48 YES [get_cells -hier -filter {REF_NAME =~ *m31_sqr*}]

# SRL inference for delay lines
set_property SHREG_EXTRACT YES [get_cells -hier -filter {NAME =~ *delay_line*}]
set_property SHREG_EXTRACT YES [get_cells -hier -filter {NAME =~ *delay_regs*}]

# ==============================================================================
#  5. Power Optimization
# ==============================================================================
# Global switching activity is set in synth_and_power.tcl

# ==============================================================================
#  6. Timing Exceptions
# ==============================================================================
# No multicycle paths needed for the iterative design.
# The FSM naturally controls the data flow.
