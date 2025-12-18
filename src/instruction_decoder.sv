module instruction_decoder(
    input  logic [31:0] instr,       // 32-bit instruction input
    output logic [4:0]  rs1,      // Source register 1 address
    output logic [4:0]  rs2,      // Source register 2 address
    output logic [4:0]  rd,       // Destination register address
    output logic [6:0]  opcode,      // Opcode field
    output logic [2:0]  func3,       // Function 3 field
    output logic [6:0]  func7        // Function 7 field
);

    // Extract fields from the instruction
    assign opcode = instr[6:0];      // Bits [6:0] - Opcode
    assign rd  = (opcode!=7'b0100011 && opcode!=7'b1100011) ? instr[11:7] : 'd0 ;     // Bits [11:7] - Destination register
    assign func3  = instr[14:12];    // Bits [14:12] - Function 3
    assign rs1 = instr[19:15];    // Bits [19:15] - Source register 1
    assign rs2 = instr[24:20];    // Bits [24:20] - Source register 2
    assign func7  = instr[31:25];    // Bits [31:25] - Function 7

endmodule