use p3_mersenne_31::Mersenne31;
use p3_field::Field;
use p3_field::PrimeField32;
use rand::Rng;

fn main() {
    println!("// ----------------------------------------------------------------");
    println!("// RUST GENERATED GOLDEN VECTORS");
    println!("// ----------------------------------------------------------------");

    // -------------------------------------------------------------------------
    // Subtraction Vectors
    // -------------------------------------------------------------------------
    println!("\n    // --- Subtraction Vectors ---");
    let sub_cases = vec![
        (0, 0),
        (1, 0),
        (1, 1),
        (0, 1),
        (100, 50),
        (50, 100),
        ((1 << 31) - 2, 0), // P-1
        (0, (1 << 31) - 2),
        ((1 << 31) - 2, (1 << 31) - 2),
    ];

    for (a_val, b_val) in sub_cases {
        let a = Mersenne31::new(a_val);
        let b = Mersenne31::new(b_val);
        let res = a - b;
        println!(
            "    check_sub(31'h{:x}, 31'h{:x}, 31'h{:x});",
            a.as_canonical_u32(),
            b.as_canonical_u32(),
            res.as_canonical_u32()
        );
    }

    // Random Subtraction
    let mut rng = rand::rng();
    for _ in 0..5 {
        let a = rng.random::<Mersenne31>();
        let b = rng.random::<Mersenne31>();
        let res = a - b;
        println!(
            "    check_sub(31'h{:x}, 31'h{:x}, 31'h{:x});",
            a.as_canonical_u32(),
            b.as_canonical_u32(),
            res.as_canonical_u32()
        );
    }

    // -------------------------------------------------------------------------
    // S-Box Vectors (x^5)
    // -------------------------------------------------------------------------
    println!("\n    // --- S-Box Vectors (x^5) ---");
    let sbox_cases = vec![
        0,
        1,
        2,
        3,
        (1 << 31) - 2, // P-1 -> (-1)^5 = -1
    ];

    for val in sbox_cases {
        let x = Mersenne31::new(val);
        // x^5
        let res = x.exp_u64(5);
        println!(
            "    check_sbox(31'h{:x}, 31'h{:x});",
            x.as_canonical_u32(),
            res.as_canonical_u32()
        );
    }

    // Random S-Box
    for _ in 0..5 {
        let x = rng.random::<Mersenne31>();
        let res = x.exp_u64(5);
        println!(
            "    check_sbox(31'h{:x}, 31'h{:x});",
            x.as_canonical_u32(),
            res.as_canonical_u32()
        );
    }
}
