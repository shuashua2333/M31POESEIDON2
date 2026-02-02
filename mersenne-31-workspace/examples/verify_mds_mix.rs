use p3_field::{PrimeCharacteristicRing, PrimeField32};
use p3_mersenne_31::Mersenne31;
use p3_poseidon2::MDSMat4;
use p3_symmetric::Permutation;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

// Reimplementing the mixing logic to match m31_mix_layer.sv
// This corresponds to the second part of mds_light_permutation in external.rs
fn apply_mix_layer(state: &mut [Mersenne31]) {
    let width = state.len();
    assert!(width % 4 == 0, "Width must be multiple of 4");
    
    // 1. Calculate Sums
    let mut sums = [Mersenne31::ZERO; 4];
    for k in 0..4 {
        let mut acc = Mersenne31::ZERO;
        for j in (k..width).step_by(4) {
             acc += state[j];
        }
        sums[k] = acc;
    }

    // 2. Add Sums to State
    for i in 0..width {
        state[i] += sums[i % 4];
    }
}

fn main() {
    let mut rng = StdRng::seed_from_u64(42);

    println!("// Generated Test Vectors for M31 MDS and Mix Layer");

    // --- Test 1: MDS 4x4 ---
    println!("\n// Test 1: MDS 4x4");
    let mut state_4 = [Mersenne31::ZERO; 4];
    for i in 0..4 {
        // Use random() instead of gen() for rand 0.9 compatibility/future proofing
        state_4[i] = Mersenne31::new(rng.random::<u32>() % ((1 << 31) - 1));
    }
    
    let input_4 = state_4;
    
    // Apply MDS
    let mds = MDSMat4::default();
    mds.permute_mut(&mut state_4);
    
    let output_4 = state_4;

    // Print vectors
    println!("// Input:");
    for i in 0..4 {
        println!("mds_in[{}] = 31'd{};", i, input_4[i].as_canonical_u32());
    }
    println!("// Expected Output:");
    for i in 0..4 {
        println!("mds_expected[{}] = 31'd{};", i, output_4[i].as_canonical_u32());
    }


    // --- Test 2: Mix Layer (Width 16) ---
    println!("\n// Test 2: Mix Layer (Width 16)");
    let mut state_16 = [Mersenne31::ZERO; 16];
    for i in 0..16 {
        state_16[i] = Mersenne31::new(rng.random::<u32>() % ((1 << 31) - 1));
    }
    
    let input_16 = state_16;
    
    // Apply Mix Layer
    apply_mix_layer(&mut state_16);
    
    let output_16 = state_16;
    
    // Print vectors
    println!("// Input:");
    for i in 0..16 {
        println!("mix_in[{}] = 31'd{};", i, input_16[i].as_canonical_u32());
    }
    println!("// Expected Output:");
    for i in 0..16 {
        println!("mix_expected[{}] = 31'd{};", i, output_16[i].as_canonical_u32());
    }
}
