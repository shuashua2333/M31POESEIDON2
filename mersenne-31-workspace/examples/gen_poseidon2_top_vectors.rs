// Generate test vectors for Poseidon2 top-level module verification
// This extracts intermediate results for FPGA debugging

use p3_field::{Field, PrimeCharacteristicRing, PrimeField32};
use p3_mersenne_31::Mersenne31;
use p3_poseidon2::{Poseidon2, MDSMat4};
use p3_symmetric::Permutation;
use rand::SeedableRng;
use rand_xoshiro::Xoroshiro128Plus;
use std::fs::File;
use std::io::Write;

// S-box function: x^5
fn sbox(x: Mersenne31) -> Mersenne31 {
    let x2 = x * x;
    let x4 = x2 * x2;
    x4 * x
}

// MDS 4x4 matrix multiplication
fn apply_mds_4x4(chunk: &mut [Mersenne31; 4]) {
    let mat = MDSMat4::default();
    mat.permute_mut(chunk);
}

// Mix layer - second part of MDS Light
fn apply_mix_layer(state: &mut [Mersenne31; 16]) {
    // Calculate sums for each position mod 4
    let mut sums = [Mersenne31::ZERO; 4];
    for k in 0..4 {
        let mut acc = Mersenne31::ZERO;
        for j in (k..16).step_by(4) {
            acc += state[j];
        }
        sums[k] = acc;
    }
    
    // Add sums to state
    for i in 0..16 {
        state[i] += sums[i % 4];
    }
}

// MDS Light = MDS 4x4 + Mix Layer
fn apply_mds_light(state: &mut [Mersenne31; 16]) {
    // Apply 4x4 MDS to each chunk
    for i in (0..16).step_by(4) {
        let mut chunk = [state[i], state[i+1], state[i+2], state[i+3]];
        apply_mds_4x4(&mut chunk);
        state[i] = chunk[0];
        state[i+1] = chunk[1];
        state[i+2] = chunk[2];
        state[i+3] = chunk[3];
    }
    
    // Apply mixing layer
    apply_mix_layer(state);
}

// Internal linear layer for WIDTH=16
fn internal_linear_layer_16(state: &mut [Mersenne31; 16]) {
    const SHIFTS: [u8; 15] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16];
    
    // Calculate sum of all elements
    let full_sum: Mersenne31 = state.iter().cloned().sum();
    let part_sum: Mersenne31 = state[1..].iter().cloned().sum();
    
    // state[0] = part_sum - state[0] = sum - 2*state[0]
    let s0 = part_sum - state[0];
    
    // state[i] = full_sum + state[i] << shifts[i-1] for i >= 1
    let mut new_state = [Mersenne31::ZERO; 16];
    new_state[0] = s0;
    
    for i in 1..16 {
        let shifted = state[i].mul_2exp_u64(SHIFTS[i - 1] as u64);
        new_state[i] = full_sum + shifted;
    }
    
    *state = new_state;
}

// Full round operation
fn full_round(
    state: &mut [Mersenne31; 16],
    round_constants: &[Mersenne31; 16],
) {
    // Step 1: Add round constants
    for i in 0..16 {
        state[i] += round_constants[i];
    }
    
    // Step 2: Apply S-box to all elements
    for i in 0..16 {
        state[i] = sbox(state[i]);
    }
    
    // Step 3: Apply MDS Light (4x4 MDS + Mix Layer)
    apply_mds_light(state);
}

// Partial round operation
fn partial_round(
    state: &mut [Mersenne31; 16],
    round_constant: Mersenne31,
) {
    // Step 1: Add constant to state[0] only
    state[0] += round_constant;
    
    // Step 2: Apply S-box to state[0] only
    state[0] = sbox(state[0]);
    
    // Step 3: Apply internal linear layer
    internal_linear_layer_16(state);
}

#[derive(Debug, Clone)]
struct Poseidon2Intermediates {
    initial_input: [Mersenne31; 16],
    after_pre_mds: [Mersenne31; 16],
    after_initial_rounds: Vec<[Mersenne31; 16]>,
    after_partial_rounds: Vec<[Mersenne31; 16]>,
    after_terminal_rounds: Vec<[Mersenne31; 16]>,
    final_output: [Mersenne31; 16],
}

fn poseidon2_with_intermediates(
    mut state: [Mersenne31; 16],
    initial_constants: &[[Mersenne31; 16]],
    partial_constants: &[Mersenne31],
    terminal_constants: &[[Mersenne31; 16]],
) -> Poseidon2Intermediates {
    let initial_input = state;
    
    // Pre-MDS (initial linear layer)
    apply_mds_light(&mut state);
    let after_pre_mds = state;
    
    // Initial full rounds
    let mut after_initial_rounds = Vec::new();
    for round_const in initial_constants {
        full_round(&mut state, round_const);
        after_initial_rounds.push(state);
    }
    
    // Partial rounds
    let mut after_partial_rounds = Vec::new();
    for &round_const in partial_constants {
        partial_round(&mut state, round_const);
        after_partial_rounds.push(state);
    }
    
    // Terminal full rounds
    let mut after_terminal_rounds = Vec::new();
    for round_const in terminal_constants {
        full_round(&mut state, round_const);
        after_terminal_rounds.push(state);
    }
    
    let final_output = state;
    
    Poseidon2Intermediates {
        initial_input,
        after_pre_mds,
        after_initial_rounds,
        after_partial_rounds,
        after_terminal_rounds,
        final_output,
    }
}

fn format_m31_array(arr: &[Mersenne31]) -> String {
    arr.iter()
        .map(|x| format!("{}", x.as_canonical_u32()))
        .collect::<Vec<_>>()
        .join(", ")
}

fn format_m31_array_hex(arr: &[Mersenne31]) -> String {
    arr.iter()
        .map(|x| format!("31'h{:08x}", x.as_canonical_u32()))
        .collect::<Vec<_>>()
        .join(", ")
}

fn main() {
    let mut file = File::create("poseidon2_top_vectors.txt").expect("Unable to create file");
    
    println!("Generating test vectors for Poseidon2 Top Module...\n");
    
    // Use the same RNG as the reference test to get the same constants
    let mut rng = Xoroshiro128Plus::seed_from_u64(1);
    let perm = p3_mersenne_31::Poseidon2Mersenne31::<16>::new_from_rng_128(&mut rng);
    
    // Extract constants from the permutation
    // We need to manually create constants for our manual implementation
    // For now, use simple test constants
    
    const N_FULL_ROUNDS_HALF: usize = 4;
    const N_PARTIAL_ROUNDS: usize = 14;
    
    // Generate simple test constants (in real implementation, these come from the RNG)
    let mut initial_constants = Vec::new();
    for i in 0..N_FULL_ROUNDS_HALF {
        let mut round_const = [Mersenne31::ZERO; 16];
        for j in 0..16 {
            round_const[j] = Mersenne31::new((i * 16 + j + 1000) as u32);
        }
        initial_constants.push(round_const);
    }
    
    let mut partial_constants = Vec::new();
    for i in 0..N_PARTIAL_ROUNDS {
        partial_constants.push(Mersenne31::new((i + 2000) as u32));
    }
    
    let mut terminal_constants = Vec::new();
    for i in 0..N_FULL_ROUNDS_HALF {
        let mut round_const = [Mersenne31::ZERO; 16];
        for j in 0..16 {
            round_const[j] = Mersenne31::new((i * 16 + j + 3000) as u32);
        }
        terminal_constants.push(round_const);
    }
    
    // Test Case 1: Sequential input
    writeln!(file, "=== POSEIDON2 TOP MODULE TEST VECTORS ===\n").unwrap();
    writeln!(file, "Configuration:").unwrap();
    writeln!(file, "  WIDTH = 16").unwrap();
    writeln!(file, "  N_FULL_ROUNDS_HALF = {}", N_FULL_ROUNDS_HALF).unwrap();
    writeln!(file, "  N_PARTIAL_ROUNDS = {}\n", N_PARTIAL_ROUNDS).unwrap();
    
    let input_state = [
        Mersenne31::new(1),
        Mersenne31::new(2),
        Mersenne31::new(3),
        Mersenne31::new(4),
        Mersenne31::new(5),
        Mersenne31::new(6),
        Mersenne31::new(7),
        Mersenne31::new(8),
        Mersenne31::new(9),
        Mersenne31::new(10),
        Mersenne31::new(11),
        Mersenne31::new(12),
        Mersenne31::new(13),
        Mersenne31::new(14),
        Mersenne31::new(15),
        Mersenne31::new(16),
    ];
    
    writeln!(file, "Test Case 1: Sequential Input\n").unwrap();
    writeln!(file, "Initial Input:").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&input_state)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&input_state)).unwrap();
    
    let intermediates = poseidon2_with_intermediates(
        input_state,
        &initial_constants,
        &partial_constants,
        &terminal_constants,
    );
    
    writeln!(file, "After Pre-MDS (Initial Linear Layer):").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&intermediates.after_pre_mds)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&intermediates.after_pre_mds)).unwrap();
    
    writeln!(file, "After Initial Full Rounds:").unwrap();
    for (i, state) in intermediates.after_initial_rounds.iter().enumerate() {
        writeln!(file, "  Round {}: [{}]", i, format_m31_array(state)).unwrap();
    }
    writeln!(file, "").unwrap();
    
    writeln!(file, "After Partial Rounds (showing first 3 and last 3):").unwrap();
    for i in 0..3.min(intermediates.after_partial_rounds.len()) {
        writeln!(file, "  Round {}: [{}]", i, format_m31_array(&intermediates.after_partial_rounds[i])).unwrap();
    }
    writeln!(file, "  ...").unwrap();
    let len = intermediates.after_partial_rounds.len();
    for i in (len.saturating_sub(3))..len {
        writeln!(file, "  Round {}: [{}]", i, format_m31_array(&intermediates.after_partial_rounds[i])).unwrap();
    }
    writeln!(file, "").unwrap();
    
    writeln!(file, "After Terminal Full Rounds:").unwrap();
    for (i, state) in intermediates.after_terminal_rounds.iter().enumerate() {
        writeln!(file, "  Round {}: [{}]", i, format_m31_array(state)).unwrap();
    }
    writeln!(file, "").unwrap();
    
    writeln!(file, "Final Output:").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&intermediates.final_output)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&intermediates.final_output)).unwrap();
    
    // Test Case 2: Using the reference implementation test vector
    writeln!(file, "\n=== TEST CASE 2: Reference Implementation Test ===\n").unwrap();
    
    let mut ref_input: [Mersenne31; 16] = Mersenne31::new_array([
        894848333, 1437655012, 1200606629, 1690012884, 71131202, 1749206695, 1717947831,
        120589055, 19776022, 42382981, 1831865506, 724844064, 171220207, 1299207443, 227047920,
        1783754913,
    ]);
    
    let expected: [Mersenne31; 16] = Mersenne31::new_array([
        1124552602, 2127602268, 1834113265, 1207687593, 1891161485, 245915620, 981277919,
        627265710, 1534924153, 1580826924, 887997842, 1526280482, 547791593, 1028672510,
        1803086471, 323071277,
    ]);
    
    writeln!(file, "Input (from reference test):").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&ref_input)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&ref_input)).unwrap();
    
    // Apply the reference permutation
    perm.permute_mut(&mut ref_input);
    
    writeln!(file, "Expected Output (from reference test):").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&expected)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&expected)).unwrap();
    
    writeln!(file, "Actual Output (from reference permutation):").unwrap();
    writeln!(file, "  Decimal: [{}]", format_m31_array(&ref_input)).unwrap();
    writeln!(file, "  Hex:     {{{}}};\n", format_m31_array_hex(&ref_input)).unwrap();
    
    if ref_input == expected {
        writeln!(file, "✓ Reference test PASSED\n").unwrap();
    } else {
        writeln!(file, "✗ Reference test FAILED\n").unwrap();
    }
    
    println!("Test vectors generated successfully to 'poseidon2_top_vectors.txt'");
}
