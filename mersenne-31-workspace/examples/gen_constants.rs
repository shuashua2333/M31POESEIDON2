use p3_field::{PrimeField, PrimeField64};
use p3_mersenne_31::Mersenne31;
use rand::SeedableRng;
use rand::Rng; // Added import for sample_iter
use rand_xoshiro::Xoroshiro128Plus;
use p3_poseidon2::ExternalLayerConstants;
use rand::distr::{Distribution, StandardUniform};

fn main() {
    let width = 16;
    let rounds_f = 8;
    let rounds_p = 14;

    let mut rng = Xoroshiro128Plus::seed_from_u64(1);

    // Generate External Constants
    let external_constants = ExternalLayerConstants::<Mersenne31, 16>::new_from_rng(rounds_f, &mut rng);
    
    // Generate Internal Constants
    // Fix: Explicit type annotation for clarity, though Vec<Mersenne31> was already there. 
    // The issue might be Rng trait scope or Xoroshiro specific interaction.
    // importing rand::Rng should fix sample_iter.
    let internal_constants: Vec<Mersenne31> = rng.sample_iter(StandardUniform).take(rounds_p).collect();

    println!("package m31_constants_pkg;");
    println!("    import m31_pkg::*;");
    println!("");
    
    println!("    // Initial Round Constants (Added before S-box)");
    println!("    // Format: round_consts_initial[round_idx][element_idx]");
    println!("    const m31_t ROUND_CONSTS_INITIAL [3:0][15:0] = '{{");
    for (r, round_consts) in external_constants.get_initial_constants().iter().enumerate() {
         print!("        '{{");
         for (i, c) in round_consts.iter().enumerate() {
             print!("31'd{}", c.as_canonical_u64());
             if i < 15 { print!(", "); }
         }
         print!("}}");
         if r < 3 { println!(","); } else { println!(""); }
    }
    println!("    }};");
    println!("");

    println!("    // Internal Round Constants (Added to first element only)");
    println!("    const m31_t ROUND_CONSTS_INTERNAL [13:0] = '{{");
    for (i, c) in internal_constants.iter().enumerate() {
        print!("31'd{}", c.as_canonical_u64());
        if i < 13 { print!(", "); }
    }
    println!("    }};");
    println!("");

    println!("    // Terminal Round Constants");
    println!("    const m31_t ROUND_CONSTS_TERMINAL [3:0][15:0] = '{{");
    for (r, round_consts) in external_constants.get_terminal_constants().iter().enumerate() {
         print!("        '{{");
         for (i, c) in round_consts.iter().enumerate() {
             print!("31'd{}", c.as_canonical_u64());
             if i < 15 { print!(", "); }
         }
         print!("}}");
         if r < 3 { println!(","); } else { println!(""); }
    }
    println!("    }};");
    
    println!("endpackage");
}
