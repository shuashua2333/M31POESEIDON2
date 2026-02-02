
use p3_field::{AbstractField, PrimeField32};
use p3_mersenne_31::Mersenne31;
use p3_poseidon2::MDSMat4;
use p3_symmetric::Permutation;
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

fn main() {
    let mut rng = StdRng::seed_from_u64(0x12345678);

    println!("// Verification Vectors for m31_mds_4x4 and m31_mix_layer");

    // 1. Verify m31_mds_4x4 (MDSMat4)
    println!("\n// --- MDS 4x4 Vectors ---");
    for i in 0..3 {
        let mut input: [Mersenne31; 4] = [
            rng.random(), rng.random(), rng.random(), rng.random()
        ];
        let original_input = input;
        
        // Use the MDSMat4 struct directly as identified in p3-poseidon2
        let mds = MDSMat4::default();
        mds.permute_mut(&mut input);
        
        println!("// Test Case {}", i);
        println!("// Input:  {:?}", original_input.iter().map(|x| x.as_canonical_u32()).collect::<Vec<_>>());
        println!("// Output: {:?}", input.iter().map(|x| x.as_canonical_u32()).collect::<Vec<_>>());
    }

    // 2. Verify m31_mix_layer (Second part of mds_light_permutation)
    // The SV module takes WIDTH=16 inputs.
    println!("\n// --- Mix Layer Vectors (Width 16) ---");
    const WIDTH: usize = 16;
    for i in 0..3 {
        let mut state: [Mersenne31; WIDTH] = core::array::from_fn(|_| rng.random());
        let original_state = state;

        // Reproducing the mix layer logic from p3-poseidon2 `mds_light_permutation`
        // Note: mds_light_permutation does BOTH MDS 4x4 AND the mixing usage.
        // We only want to test the mixing part here to match m31_mix_layer.sv.
        
        // We first precompute the four sums of every four elements.
        let sums: [Mersenne31; 4] =
            core::array::from_fn(|k| (0..WIDTH).step_by(4).map(|j| state[j + k].clone()).sum());

        // The formula: add appropriate sum to each element
        let mut output = state;
        output
            .iter_mut()
            .enumerate()
            .for_each(|(i, elem)| *elem += sums[i % 4].clone());

        println!("// Test Case {}", i);
        println!("// Input:");
        for chunk in original_state.chunks(4) {
             println!("//  {:?}", chunk.iter().map(|x| x.as_canonical_u32()).collect::<Vec<_>>());
        }
        println!("// Output:");
        for chunk in output.chunks(4) {
             println!("//  {:?}", chunk.iter().map(|x| x.as_canonical_u32()).collect::<Vec<_>>());
        }
    }
}
