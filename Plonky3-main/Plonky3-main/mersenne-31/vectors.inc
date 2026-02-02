// A=00000000, B=00000000 -> Sum=00000000, Prod=00000000
check_vector(31'h0, 31'h0, 31'h0, 31'h0);
// A=00000001, B=00000001 -> Sum=00000002, Prod=00000001
check_vector(31'h1, 31'h1, 31'h2, 31'h1);
// A=7ffffffe, B=00000001 -> Sum=00000000, Prod=7ffffffe
check_vector(31'h7ffffffe, 31'h1, 31'h0, 31'h7ffffffe);
// A=7ffffffe, B=7ffffffe -> Sum=7ffffffd, Prod=00000001
check_vector(31'h7ffffffe, 31'h7ffffffe, 31'h7ffffffd, 31'h1);
// A=2e413a1f, B=16332d59 -> Sum=44746778, Prod=52175c24
check_vector(31'h2e413a1f, 31'h16332d59, 31'h44746778, 31'h52175c24);
// A=01eed090, B=1b66d324 -> Sum=1d55a3b4, Prod=6545f1bc
check_vector(31'h1eed090, 31'h1b66d324, 31'h1d55a3b4, 31'h6545f1bc);
// A=6ec7a966, B=2cb0c277 -> Sum=1b786bde, Prod=71fca77b
check_vector(31'h6ec7a966, 31'h2cb0c277, 31'h1b786bde, 31'h71fca77b);
// A=0678baf5, B=41dce872 -> Sum=4855a367, Prod=2e11c34c
check_vector(31'h678baf5, 31'h41dce872, 31'h4855a367, 31'h2e11c34c);
// A=24c1a869, B=12b0899e -> Sum=37723207, Prod=02340f49
check_vector(31'h24c1a869, 31'h12b0899e, 31'h37723207, 31'h2340f49);
// A=44d04ecf, B=236d8852 -> Sum=683dd721, Prod=22c60e87
check_vector(31'h44d04ecf, 31'h236d8852, 31'h683dd721, 31'h22c60e87);
// A=5ebb8073, B=72641f2f -> Sum=511f9fa3, Prod=508f9a14
check_vector(31'h5ebb8073, 31'h72641f2f, 31'h511f9fa3, 31'h508f9a14);
// A=4c9b1162, B=67112086 -> Sum=33ac31e9, Prod=4e886158
check_vector(31'h4c9b1162, 31'h67112086, 31'h33ac31e9, 31'h4e886158);
// A=7b1ed0e3, B=61ae4bec -> Sum=5ccd1cd0, Prod=62da137b
check_vector(31'h7b1ed0e3, 31'h61ae4bec, 31'h5ccd1cd0, 31'h62da137b);
// A=488de342, B=17f7ee0d -> Sum=6085d14f, Prod=58bfedeb
check_vector(31'h488de342, 31'h17f7ee0d, 31'h6085d14f, 31'h58bfedeb);
