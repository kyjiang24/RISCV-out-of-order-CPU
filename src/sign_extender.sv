// ======================================
// sign_extender.sv - Sign Extension Unit
// ======================================

module sign_extender (
    input  logic [31:0] instr,
    output logic [31:0] imm_out
);

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        case (opcode)
            7'b0010011: imm_out = {{20{instr[31]}}, instr[31:20]}; // I-type (ADDI, etc.)
            7'b0000011: imm_out = {{20{instr[31]}}, instr[31:20]}; // Load

            7'b1100011: imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type

            7'b1101111: imm_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // JAL
            7'b0100011: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type (Store)
            default: imm_out = 32'b0;
        endcase
		//$display("[IMM] instruction = %h, imm32 = %h", instr, imm_out);
    end

endmodule
