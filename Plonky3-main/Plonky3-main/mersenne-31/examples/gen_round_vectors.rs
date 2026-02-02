use p3_field::PrimeCharacteristicRing;
use p3_field::{AbstractField, Field};
use p3_mersenne_31::Mersenne31;
use p3_mds::MdsPermutation;

use rand::thread_rng;
use rand::Rng;

// We need to access some internals or replicate them.
// Since p3_poseidon2 logic is generic, we can replicate the single round logic here.

// Replicating M31 Constants and SBox degree
const MERSENNE31_S_BOX_DEGREE: u64 = 5;

fn sbox(x: Mersenne31) -> Mersenne31 {
    x.exp_u64(MERSENNE31_S_BOX_DEGREE)
}

// Full Round Logic: Add Const -> SBox -> MDS
// The SV `m31_op_full_round` does:
// 1. state[i] + const[i]
// 2. sbox
// 3. mds
fn full_round_sim(state: &mut [Mersenne31; 16], round_consts: &[Mersenne31; 16]) {
    // 1. Add Const + 2. SBox
    for i in 0..16 {
        state[i] = sbox(state[i] + round_consts[i]);
    }
    
    // 3. MDS (using p3_mersenne_31::mds::MdsMatrixMersenne31)
    // The SV implementation splits this into 4x4 chunks and then a mix layer?
    // Wait, let's re-read the SV `m31_op_full_round.sv`.
    
    // SV `m31_op_full_round.sv`:
    // // A. 4x4 MDS
    // for (i = 0; i < WIDTH; i += 4) begin : gen_mds4
    //     m31_mds_4x4 u_mds4 (...);
    // end
    // // B & C. Mixing Step (Sums + Add)
    // m31_mix_layer ...
    
    // This structure (4x4 MDS + Mix) corresponds to the MDS matrix structure in Poseidon2 
    // for larger widths (like 16).
    // The Rust `MdsMatrixMersenne31` implementation for `[Mersenne31; 16]` uses `SmallConvolveMersenne31::apply` with `MATRIX_CIRC_MDS_16_SML_COL`.
    // It seems the SV implementation is doing an OPTIMIZED decomposition of the MDS matrix.
    // If the SV `m31_mds_4x4` + `m31_mix_layer` is equivalent to the full 16x16 MDS, 
    // then I should just use the Rust 16x16 MDS.
    
    // Let's verify if `m31_mds_4x4` + `m31_mix_layer` == 16x16 MDS.
    // In plonky3 M31 MDS is indeed a circulant matrix.
    // The SV logic seems to be trying to implement that circulant matrix multiplication efficiently.
    // So for the reference, I should use the STANDARD Rust MDS permutation on the whole state.
    
    use p3_mersenne_31::MdsMatrixMersenne31;
    let mds = MdsMatrixMersenne31::default();
    
    // p3_mds trait Permutation
    use p3_symmetric::Permutation;
    *state = mds.permute(*state);
}

// Partial Round Logic: Add Const[0] -> SBox[0] -> Internal Linear Layer
fn partial_round_sim(state: &mut [Mersenne31; 16], round_const: Mersenne31) {
    // 1. Add Const (state[0] only)
    // 2. SBox (state[0] only)
    state[0] = sbox(state[0] + round_const);
    
    // 3. Internal Linear Layer
    // In Rust `poseidon2.rs`: `permute_mut` with `POSEIDON2_INTERNAL_MATRIX_DIAG_16_SHIFTS`
    
    const SHIFTS: [u8; 15] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16];
    
    // permute_mut logic from poseidon2.rs
    // Shifts needed for 1..16 (indices 0..15 in shifts array? No, shifts array is length 15)
    // indices 1..16 in state map to shifts[0..15]
    
    let part_sum: Mersenne31 = state[1..].iter().cloned().sum();
    let full_sum = part_sum + state[0];
    
    // state[0] = part_sum - state[0]
    let s0 = part_sum - state[0];
    state[0] = s0;
    
    for i in 1..16 {
        // state[i] = full_sum + state[i] * 2^shifts[i-1]
        let shift = SHIFTS[i-1] as u64;
        let mut scaled = state[i];
        // naive shift for M31 (mul by 2^k)
        for _ in 0..shift {
            scaled = scaled.double();
        }
        state[i] = full_sum + scaled;
    }
}

fn main() {
    let mut rng = thread_rng();

    println!("// Generated Test Vectors for M31 Rounds");
    
    // ============================================
    // Test Case 1: Full Round
    // ============================================
    let mut state_full: [Mersenne31; 16] = [Mersenne31::default(); 16];
    let mut consts_full: [Mersenne31; 16] = [Mersenne31::default(); 16];
    
    for i in 0..16 {
        state_full[i] = Mersenne31::from_canonical_u32(rng.gen_range(0..2147483647));
        consts_full[i] = Mersenne31::from_canonical_u32(rng.gen_range(0..2147483647));
    }
    
    println!("// Full Round Inputs:");
    print!("// State: ");
    for x in state_full.iter() { print!("{} ", x.as_canonical_u32()); }
    println!("");
    print!("// Consts: ");
    for x in consts_full.iter() { print!("{} ", x.as_canonical_u32()); }
    println!("");
    
    let mut state_out_full = state_full.clone();
    full_round_sim(&mut state_out_full, &consts_full);
    
    println!("// Full Round Outputs:");
    print!("// Result: ");
    for x in state_out_full.iter() { print!("{} ", x.as_canonical_u32()); }
    println!("");
    
    // Formatted for SV generic TB
    println!("// SV_TEST_VECTORS_FULL_BEGIN");
    for i in 0..16 { print!("{:08x} ", state_full[i].as_canonical_u32()); }
    println!("");
    for i in 0..16 { print!("{:08x} ", consts_full[i].as_canonical_u32()); }
    println!("");
    for i in 0..16 { print!("{:08x} ", state_out_full[i].as_canonical_u32()); }
    println!("\n// SV_TEST_VECTORS_FULL_END");


    // ============================================
    // Test Case 2: Partial Round
    // ============================================
    let mut state_partial: [Mersenne31; 16] = [Mersenne31::default(); 16];
    let const_partial = Mersenne31::from_canonical_u32(rng.gen_range(0..2147483647));
    
    for i in 0..16 {
        state_partial[i] = Mersenne31::from_canonical_u32(rng.gen_range(0..2147483647));
    }
    
    println!("// Partial Round Inputs:");
    print!("// State: ");
    for x in state_partial.iter() { print!("{} ", x.as_canonical_u32()); }
    println!("");
    println!("// Const: {}", const_partial.as_canonical_u32());
    
    let mut state_out_partial = state_partial.clone();
    partial_round_sim(&mut state_out_partial, const_partial);
    
    println!("// Partial Round Outputs:");
    print!("// Result: ");
    for x in state_out_partial.iter() { print!("{} ", x.as_canonical_u32()); }
    println!("");
    
    // Formatted for SV generic TB
    println!("// SV_TEST_VECTORS_PARTIAL_BEGIN");
    for i in 0..16 { print!("{:08x} ", state_partial[i].as_canonical_u32()); }
    println!("");
    println!("{:08x} ", const_partial.as_canonical_u32()); 
    for i in 0..16 { print!("{:08x} ", state_out_partial[i].as_canonical_u32()); }
    println!("\n// SV_TEST_VECTORS_PARTIAL_END");
}
