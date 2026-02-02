//! Dump Poseidon2 round constants for RTL verification

use p3_field::PrimeField32;
use p3_mersenne_31::Mersenne31;
use rand::SeedableRng;
use rand_xoshiro::Xoroshiro128Plus;
use rand::Rng;

fn main() {
    let mut rng = Xoroshiro128Plus::seed_from_u64(1);
    
    // Round numbers for M31 width 16 with 128-bit security
    // rounds_f = 8 (4 initial + 4 terminal), rounds_p = 14
    let rounds_f = 8;
    let rounds_p = 14;
    let half_f = rounds_f / 2; // 4
    
    println!("=== Poseidon2 M31 Width=16 Round Constants ===");
    println!("rounds_f = {} (half = {})", rounds_f, half_f);
    println!("rounds_p = {}", rounds_p);
    
    // Generate external constants (initial + terminal)
    println!("\n=== INITIAL External Round Constants (4 rounds x 16 elements) ===");
    for round in 0..half_f {
        print!("Round {}: {{", round);
        for i in 0..16 {
            let val: Mersenne31 = rng.random();
            print!("{}", val.as_canonical_u32());
            if i < 15 { print!(", "); }
        }
        println!("}}");
    }
    
    println!("\n=== TERMINAL External Round Constants (4 rounds x 16 elements) ===");
    for round in 0..half_f {
        print!("Round {}: {{", round);
        for i in 0..16 {
            let val: Mersenne31 = rng.random();
            print!("{}", val.as_canonical_u32());
            if i < 15 { print!(", "); }
        }
        println!("}}");
    }
    
    println!("\n=== INTERNAL Round Constants (14 elements, one per partial round) ===");
    print!("{{");
    for i in 0..rounds_p {
        let val: Mersenne31 = rng.random();
        print!("{}", val.as_canonical_u32());
        if i < rounds_p - 1 { print!(", "); }
    }
    println!("}}");
    
    println!("\n=== SystemVerilog Format ===");
    
    // Reset RNG to regenerate
    let mut rng = Xoroshiro128Plus::seed_from_u64(1);
    
    println!("\n// Initial Round Constants");
    println!("localparam state16_t ROUND_CONSTS_INITIAL [0:3] = '{{");
    for round in 0..half_f {
        print!("    '{{");
        for i in 0..16 {
            let val: Mersenne31 = rng.random();
            print!("31'd{}", val.as_canonical_u32());
            if i < 15 { print!(", "); }
        }
        if round < half_f - 1 { println!("}},")} else { println!("}}") }
    }
    println!("}};");
    
    println!("\n// Terminal Round Constants");
    println!("localparam state16_t ROUND_CONSTS_TERMINAL [0:3] = '{{");
    for round in 0..half_f {
        print!("    '{{");
        for i in 0..16 {
            let val: Mersenne31 = rng.random();
            print!("31'd{}", val.as_canonical_u32());
            if i < 15 { print!(", "); }
        }
        if round < half_f - 1 { println!("}},")} else { println!("}}") }
    }
    println!("}};");
    
    println!("\n// Internal Round Constants");
    print!("localparam m31_t ROUND_CONSTS_INTERNAL [0:13] = '{{");
    for i in 0..rounds_p {
        let val: Mersenne31 = rng.random();
        print!("31'd{}", val.as_canonical_u32());
        if i < rounds_p - 1 { print!(", "); }
    }
    println!("}};");
}
