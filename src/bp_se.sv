module bp_se (
    input  logic [31:0] instr,         // Current instruction
    input  logic [31:0] pc,            // Current PC

    output logic        is_branch,     // Is this a branch instruction
    output logic [31:0] branch_target  // Target PC if taken
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [31:0] imm_b;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];

    // Identify branch instructions (opcode = 1100011)
    assign is_branch = (opcode == 7'b1100011);

    // Decode B-type immediate (signed, already shifted left by 1)
    always_comb begin
        imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    end

    // Compute branch target
    assign branch_target = pc + imm_b;

endmodule
