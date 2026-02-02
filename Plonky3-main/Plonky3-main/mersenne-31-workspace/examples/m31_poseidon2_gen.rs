use p3_field::{Field, PrimeField32, PrimeField, PrimeCharacteristicRing};
use p3_mersenne_31_test::{Mersenne31, Poseidon2ExternalLayerMersenne31, Poseidon2InternalLayerMersenne31};
use p3_poseidon2::{ExternalLayerConstants, ExternalLayerConstructor, InternalLayerConstructor, MDSMat4, mds_light_permutation, poseidon2_round_numbers_128};
use p3_symmetric::Permutation; 
use rand::{SeedableRng, Rng};
use rand_xoshiro::Xoroshiro128Plus;
use rand::distr::{Distribution, StandardUniform};

const WIDTH: usize = 16;
const D: u64 = 5;

// Helper to print state
fn print_state(label: &str, state: &[Mersenne31; WIDTH]) {
    println!("{}", label);
    for x in state {
        print!("{:08x} ", x.as_canonical_u32());
    }
    println!("");
}

fn from_u62(val: u64) -> Mersenne31 {
    let val_u32 = (val % ((1u64 << 31) - 1)) as u32;
    Mersenne31::new(val_u32)
}

fn permute_internal_m31(state: &mut [Mersenne31; WIDTH]) {
    let shifts: [u8; 15] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 13, 14, 15, 16];
    
    let mut part_sum: u64 = 0;
    for i in 1..WIDTH {
        part_sum += state[i].as_canonical_u32() as u64;
    }
    
    let state0 = state[0].as_canonical_u32() as u64;
    let full_sum = part_sum + state0;
    
    // s0 = part_sum - state[0] = part_sum + (-state[0])
    let neg_state0 = if state0 == 0 { 0 } else { 2147483647 - state0 }; // 2^31-1
    let s0 = part_sum + neg_state0;
    
    state[0] = from_u62(s0);
    
    for i in 1..WIDTH {
        // si = full_sum + (state[i] << shift)
        let si = full_sum + ((state[i].as_canonical_u32() as u64) << shifts[i-1]);
        state[i] = from_u62(si);
    }
}

// S-box x^5
fn sbox(x: &mut Mersenne31) {
    let val = *x;
    *x = val.exp_u64(5);
}

fn run_permutation(input: [Mersenne31; WIDTH]) -> [Mersenne31; WIDTH] {
    let mut rng = Xoroshiro128Plus::seed_from_u64(1);
    let (rounds_f, rounds_p) = poseidon2_round_numbers_128::<Mersenne31>(WIDTH, D).unwrap();
    
    let external_constants = ExternalLayerConstants::<Mersenne31, WIDTH>::new_from_rng(rounds_f, &mut rng);
    let internal_constants: Vec<Mersenne31> = rng.sample_iter(StandardUniform).take(rounds_p).collect();
    
    let mut state = input;

    // --- Initial External ---
    mds_light_permutation(&mut state, &MDSMat4);
    
    let initial_consts = external_constants.get_initial_constants();
    for (r, consts) in initial_consts.iter().enumerate() {
        for (i, c) in consts.iter().enumerate() {
            state[i] += *c;
            sbox(&mut state[i]);
        }
        mds_light_permutation(&mut state, &MDSMat4);
    }
    
    // --- Internal ---
    for (r, c) in internal_constants.iter().enumerate() {
        state[0] += *c;
        sbox(&mut state[0]);
        permute_internal_m31(&mut state);
    }
    
    // --- Terminal External ---
    let terminal_consts = external_constants.get_terminal_constants();
    for (r, consts) in terminal_consts.iter().enumerate() {
        for (i, c) in consts.iter().enumerate() {
            state[i] += *c;
            sbox(&mut state[i]);
        }
        mds_light_permutation(&mut state, &MDSMat4);
    }
    
    state
}

fn main() {
    // Case 2: Reference Implementation Test (Verify setup)
    let case2_input_u32 = [
        0x35564d4d, 0x55b0dfe4, 0x478fcda5, 0x64bb8cd4,
        0x043d6042, 0x6842c6a7, 0x6665cdb7, 0x07300aff,
        0x012dc216, 0x0286b685, 0x6d300ca2, 0x2b343e20,
        0x0a349cef, 0x4d705513, 0x0d8879f0, 0x6a51f0a1,
    ];
    let case2_input: [Mersenne31; WIDTH] = core::array::from_fn(|i| Mersenne31::new(case2_input_u32[i]));
    
    let case2_output = run_permutation(case2_input);
    println!("=== Case 2 Result ===");
    for (i, x) in case2_output.iter().enumerate() {
        println!("Index {}: {:08x}", i, x.as_canonical_u32());
    }

    // Case 1: Sequential Input
    let case1_input_u32: Vec<u32> = (1..=16).collect();
    let case1_input: [Mersenne31; WIDTH] = core::array::from_fn(|i| Mersenne31::new(case1_input_u32[i]));
    
    let case1_output = run_permutation(case1_input);
    println!("\n=== Case 1 Result ===");
    for (i, x) in case1_output.iter().enumerate() {
        println!("expected_1[{}]  = 31'h{:08x};", i, x.as_canonical_u32());
    }
}
