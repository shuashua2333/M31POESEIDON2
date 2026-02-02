use p3_field::{AbstractField, Field, PrimeField32, PrimeField};
use p3_mersenne_31::{Mersenne31, Poseidon2ExternalLayerMersenne31, Poseidon2InternalLayerMersenne31};
use p3_poseidon2::{ExternalLayerConstants, ExternalLayerConstructor, InternalLayerConstructor, MDSMat4, mds_light_permutation, poseidon2_round_numbers_128, add_rc_and_sbox_generic}; 
use p3_symmetric::Permutation; 
use rand::SeedableRng;
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
    Mersenne31::from_canonical_u32(val_u32)
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

fn main() {
    // 1. Setup
    let mut rng = Xoroshiro128Plus::seed_from_u64(1);
    let (rounds_f, rounds_p) = poseidon2_round_numbers_128::<Mersenne31>(WIDTH, D).unwrap();
    
    // Generate Constants
    let external_constants = ExternalLayerConstants::<Mersenne31, WIDTH>::new_from_rng(rounds_f, &mut rng);
    let internal_constants: Vec<Mersenne31> = rng.sample_iter(StandardUniform).take(rounds_p).collect();
    
    // 2. Initial State
    let mut state: [Mersenne31; WIDTH] = core::array::from_fn(|i| Mersenne31::from_canonical_u32(i as u32));
    
    println!("// rounds_f={}, rounds_p={}", rounds_f, rounds_p);
    println!("// Initial State");
    print_state("// INIT:", &state);
    
    // 3. Execution
    
    // --- Initial External ---
    // mds_light
    mds_light_permutation(&mut state, &MDSMat4);
    print_state("// After Pre-MDS:", &state);
    
    let initial_consts = external_constants.get_initial_constants();
    for (r, consts) in initial_consts.iter().enumerate() {
        // Add RC + SBox
        for (i, c) in consts.iter().enumerate() {
            state[i] += *c;
            sbox(&mut state[i]);
        }
        print_state(&format!("// After Round {} Add+SBox:", r), &state);
        
        // MDS Light
        mds_light_permutation(&mut state, &MDSMat4);
        print_state(&format!("// After Round {} MDS:", r), &state);
    }
    
    // --- Internal ---
    for (r, c) in internal_constants.iter().enumerate() {
        // Add RC + SBox (Partial)
        state[0] += *c;
        sbox(&mut state[0]);
        print_state(&format!("// After Partial Round {} Add+SBox:", r), &state);
        
        // Diffusion
        permute_internal_m31(&mut state);
        print_state(&format!("// After Partial Round {} Diffusion:", r), &state);
    }
    
    // --- Terminal External ---
    let terminal_consts = external_constants.get_terminal_constants();
    for (r, consts) in terminal_consts.iter().enumerate() {
        // Add RC + SBox
        for (i, c) in consts.iter().enumerate() {
            state[i] += *c;
            sbox(&mut state[i]);
        }
        print_state(&format!("// After Terminal Round {} Add+SBox:", r), &state);
        
        // MDS Light
        mds_light_permutation(&mut state, &MDSMat4);
        print_state(&format!("// After Terminal Round {} MDS:", r), &state);
    }
    
    println!("// Final State");
    print_state("// FINAL:", &state);
    
    // Dump Constants for SV Package Check
    println!("\n// Constants Dump");
    for (i, c) in initial_consts.iter().enumerate() {
         print!("// Initial [{}]: ", i);
         for val in c { print!("{} ", val.as_canonical_u32()); }
         println!("");
    }
    
    print!("// Internal: ");
    for c in &internal_constants {
        print!("{} ", c.as_canonical_u32());
    }
    println!("");
    
    for (i, c) in terminal_consts.iter().enumerate() {
         print!("// Terminal [{}]: ", i);
         for val in c { print!("{} ", val.as_canonical_u32()); }
         println!("");
    }
}
