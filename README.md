# M31 Poseidon2 FPGA Implementation

This repository contains the SystemVerilog implementation of the M31 Poseidon2 hash function, designed for FPGA acceleration. The implementation is verified against the official Rust reference from Plonky3.

## Project Structure

- **`rtl/`**: SystemVerilog source code for the Poseidon2 implementation.
- **`tb/`**: Testbench files for simulation and verification.
- **`mersenne-31-workspace/`**: Rust workspace for generating test vectors and reference outputs.
- **`scripts/`**: Utility scripts (e.g., for Vivado implementation, notifications).
- **`constraints/`**: XDC constraint files for FPGA synthesis and implementation.

## Key Features

- **Field Arithmetic**: Implements operations in the Mersenne-31 field ($2^{31}-1$).
- **Pipeline Architecture**: Fully pipelined design with a depth of 23 clock cycles.
- **Performance**: Targeted for 100MHz operation.
- **Verification**: 
  - Validated against Rust reference implementation.
  - Comprehensive testbenches covering sequential inputs, random vectors, and corner cases.

## Usage

### Simulation
Refer to [SIMULATION_GUIDE.md](SIMULATION_GUIDE.md) for detailed instructions on running simulations in Vivado.

1. Add `rtl` and `tb` files to your Vivado project.
2. Set `tb_m31_poseidon2_top` as the top module for simulation.
3. Run behavioral simulation.

### Synthesis & Implementation
The project is set up for Xilinx Vivado. Use the provided scripts and constraints in `scripts/` and `constraints/` to run synthesis and implementation flows.

## Reference
- **Plonky3**: This implementation follows the Poseidon2 specification used in [Plonky3](https://github.com/Plonky3/Plonky3).

## Documentation
- [Verification Report](VERIFICATION_REPORT_TOP.md) - Detailed verification results.
- [中文验证总结](验证总结_顶层模块.md) - Summary of verification in Chinese.
