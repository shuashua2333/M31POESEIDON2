// Generate test vectors for full round and partial round verification
// This extracts intermediate results for FPGA debugging

use p3_field::{Field, PrimeCharacteristicRing, PrimeField32};
use p3_mersenne_31::Mersenne31;
use p3_poseidon2::MDSMat4;
use p3_symmetric::Permutation;
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
) -> FullRoundIntermediates {
    let input = *state;
    
    // Step 1: Add round constants
    let mut after_add = [Mersenne31::ZERO; 16];
    for i in 0..16 {
        after_add[i] = state[i] + round_constants[i];
    }
    
    // Step 2: Apply S-box to all elements
    let mut after_sbox = [Mersenne31::ZERO; 16];
    for i in 0..16 {
        after_sbox[i] = sbox(after_add[i]);
    }
    
    // Step 3a: Apply 4x4 MDS to each chunk
    let mut after_mds = after_sbox;
    for i in (0..16).step_by(4) {
        let mut chunk = [after_mds[i], after_mds[i+1], after_mds[i+2], after_mds[i+3]];
        apply_mds_4x4(&mut chunk);
        after_mds[i] = chunk[0];
        after_mds[i+1] = chunk[1];
        after_mds[i+2] = chunk[2];
        after_mds[i+3] = chunk[3];
    }
    
    // Step 3b: Apply mixing layer (MDS Light)
    let mut output = after_mds;
    apply_mix_layer(&mut output);
    
    *state = output;
    
    FullRoundIntermediates {
        input,
        after_add,
        after_sbox,
        after_mds,
        output,
    }
}

// Partial round operation
fn partial_round(
    state: &mut [Mersenne31; 16],
    round_constant: Mersenne31,
) -> PartialRoundIntermediates {
    let input = *state;
    
    // Step 1: Add constant to state[0] only
    let after_add_0 = state[0] + round_constant;
    
    // Step 2: Apply S-box to state[0] only
    let after_sbox_0 = sbox(after_add_0);
    
    // Update state[0]
    state[0] = after_sbox_0;
    
    // Step 3: Apply internal linear layer
    let before_linear = *state;
    internal_linear_layer_16(state);
    let output = *state;
    
    PartialRoundIntermediates {
        input,
        after_add_0,
        after_sbox_0,
        before_linear,
        output,
    }
}

#[derive(Debug)]
struct FullRoundIntermediates {
    input: [Mersenne31; 16],
    after_add: [Mersenne31; 16],
    after_sbox: [Mersenne31; 16],
    after_mds: [Mersenne31; 16],
    output: [Mersenne31; 16],
}

#[derive(Debug)]
struct PartialRoundIntermediates {
    input: [Mersenne31; 16],
    after_add_0: Mersenne31,
    after_sbox_0: Mersenne31,
    before_linear: [Mersenne31; 16],
    output: [Mersenne31; 16],
}

fn format_m31_array(arr: &[Mersenne31]) -> String {
    arr.iter()
        .map(|x| format!("{}", x.as_canonical_u32()))
        .collect::<Vec<_>>()
        .join(", ")
}

fn main() {
    let mut file = File::create("round_test_vectors.txt").expect("Unable to create file");
    
    // Test case 1: Simple test with known values
    println!("Generating test vectors for Full Round and Partial Round...\n");
    
    // Test Full Round
    writeln!(file, "=== FULL ROUND TEST VECTORS ===\n").unwrap();
    
    let mut state = [
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
    
    let round_constants = [
        Mersenne31::new(100),
        Mersenne31::new(200),
        Mersenne31::new(300),
        Mersenne31::new(400),
        Mersenne31::new(500),
        Mersenne31::new(600),
        Mersenne31::new(700),
        Mersenne31::new(800),
        Mersenne31::new(900),
        Mersenne31::new(1000),
        Mersenne31::new(1100),
        Mersenne31::new(1200),
        Mersenne31::new(1300),
        Mersenne31::new(1400),
        Mersenne31::new(1500),
        Mersenne31::new(1600),
    ];
    
    writeln!(file, "Test Case 1: Sequential Input").unwrap();
    writeln!(file, "Input State: [{}]", format_m31_array(&state)).unwrap();
    writeln!(file, "Round Constants: [{}]", format_m31_array(&round_constants)).unwrap();
    
    let intermediates = full_round(&mut state, &round_constants);
    
    writeln!(file, "\nIntermediates:").unwrap();
    writeln!(file, "After Add RC: [{}]", format_m31_array(&intermediates.after_add)).unwrap();
    writeln!(file, "After S-Box: [{}]", format_m31_array(&intermediates.after_sbox)).unwrap();
    writeln!(file, "After 4x4 MDS: [{}]", format_m31_array(&intermediates.after_mds)).unwrap();
    writeln!(file, "Output (After Mix): [{}]", format_m31_array(&intermediates.output)).unwrap();
    writeln!(file, "\n").unwrap();
    
    // Test Partial Round
    writeln!(file, "=== PARTIAL ROUND TEST VECTORS ===\n").unwrap();
    
    let mut state = [
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
    
    let round_constant = Mersenne31::new(12345);
    
    writeln!(file, "Test Case 1: Sequential Input").unwrap();
    writeln!(file, "Input State: [{}]", format_m31_array(&state)).unwrap();
    writeln!(file, "Round Constant: {}", round_constant.as_canonical_u32()).unwrap();
    
    let intermediates = partial_round(&mut state, round_constant);
    
    writeln!(file, "\nIntermediates:").unwrap();
    writeln!(file, "After Add RC (state[0]): {}", intermediates.after_add_0.as_canonical_u32()).unwrap();
    writeln!(file, "After S-Box (state[0]): {}", intermediates.after_sbox_0.as_canonical_u32()).unwrap();
    writeln!(file, "Before Linear Layer: [{}]", format_m31_array(&intermediates.before_linear)).unwrap();
    writeln!(file, "Output (After Linear): [{}]", format_m31_array(&intermediates.output)).unwrap();
    writeln!(file, "\n").unwrap();
    
    // Additional test cases with different patterns
    // Test Case 2: All zeros
    writeln!(file, "=== ADDITIONAL TEST CASES ===\n").unwrap();
    
    let mut state = [Mersenne31::ZERO; 16];
    let round_constants = [Mersenne31::new(1000); 16];
    
    writeln!(file, "Full Round Test Case 2: All Zeros Input").unwrap();
    writeln!(file, "Input State: [{}]", format_m31_array(&state)).unwrap();
    let intermediates = full_round(&mut state, &round_constants);
    writeln!(file, "Output: [{}]", format_m31_array(&intermediates.output)).unwrap();
    writeln!(file, "\n").unwrap();
    
    // Test Case 3: Large values
    let mut state = [Mersenne31::new(2147483646); 16];
    
    writeln!(file, "Partial Round Test Case 2: Large Values").unwrap();
    writeln!(file, "Input State: [{}]", format_m31_array(&state)).unwrap();
    let intermediates = partial_round(&mut state, Mersenne31::new(1));
    writeln!(file, "Output: [{}]", format_m31_array(&intermediates.output)).unwrap();
    
    println!("Test vectors generated successfully to 'round_test_vectors.txt'");
}
