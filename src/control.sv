module control (
    input  logic [6:0]  opcode,
    output logic        branch,
    output logic        jal,
    output logic        alu_src1, // ALU source 1 (0: rs1, 1: pc)
    output logic        alu_src2, // ALU source 2 (0: rs2, 1: imm)
    output logic [1:0]  alu_op, // ALU operation 
    output logic        rs1_used, // Indicates if rs1 is used
    output logic        rs2_used,
    output logic        load,
    output logic        store
);

    // Define opcode parameters for readability
    typedef enum logic [6:0] {
        OPCODE_RTYPE   = 7'b0110011, // Register-register arithmetic
        OPCODE_ITYPE   = 7'b0010011, // I-type arithmetic/logic (addi, andi, etc.)
        OPCODE_LOAD    = 7'b0000011, // Loads (lw, lh, lb, etc.)
        OPCODE_STORE   = 7'b0100011, // Stores (sw, sh, sb)
        OPCODE_BRANCH  = 7'b1100011, // Branch (beq, bne, etc.)
        OPCODE_JAL     = 7'b1101111 // jal
    } opcode_t;	

    always_comb begin
        // Default values
        branch     = 0;
        jal         = 0;
        alu_src1    = 0;
        alu_src2    = 0;
        alu_op     = 2'b00;
        rs1_used    = 1; // Default to using rs1
        rs2_used    = 1;
        load       = 0; // Default to not a load operation
        store      = 0; // Default to not a store operation
        case (opcode)
            // R-type: e.g., add, sub, mul, div, etc.
            OPCODE_RTYPE: begin
                branch     = 0;
                jal        = 0;
                alu_src1    = 0;
                alu_src2    = 0; // R-type uses rs2
                alu_op     = 2'b10;
                rs1_used  = 1; // R-type uses rs1
                rs2_used  = 1; // R-type uses rs2
                load    = 0; // R-type is not a load operation
                store   = 0; // R-type is not a store operation
            end 
            // I-type (addi )
            OPCODE_ITYPE: begin
                branch     = 0;
                jal        = 0;
                alu_src1    = 0;
                alu_src2    = 1; // I-type uses immediate value
                alu_op     = 2'b11;
                rs1_used  = 1; // I-type uses rs1
                rs2_used  = 0; // I-type does not use rs2
                load       = 0; // I-type is not a load operation
                store      = 0; // I-type is not a store operation
            end
            // Load (e.g., lw, lb, lh)
            OPCODE_LOAD: begin
                branch     = 0;
                jal        = 0;
                alu_src1    = 0; // Load uses rs1
                alu_src2    = 1; // Load uses immediate value
                alu_op     = 2'b11;
                rs1_used  = 1; // Load uses rs1
                rs2_used  = 0; // Load does not use rs2
                load       = 1; // Load operation
                store      = 0; // Load is not a store operation
            end
            // Store (e.g., sw, sh, sb)
            OPCODE_STORE: begin
                branch     = 0;
                jal        = 0;
                alu_src1    = 0; // Store uses rs1
                alu_src2    = 0; // Store uses immediate value
                alu_op     = 2'b11;
                rs1_used  = 1; // Store uses rs1
                rs2_used  = 1; // Store does not use rs2
                load       = 0; // Store is not a load operation
                store      = 1; // Store operation
            end
            // Branch instructions (e.g., beq, bne)
            ////////question: Should we use rs1 or PC as source 1? where to see which branch type
            OPCODE_BRANCH: begin
                branch     = 1;
                jal        = 0;
                alu_src1    = 0; // Branch uses rs1
                alu_src2    = 0; // Branch uses rs2
                alu_op     = 2'b01;
                rs1_used  = 1; // Branch uses rs1
                rs2_used  = 1; // Branch uses rs2
                load       = 0; // Branch is not a load operation
                store      = 0; // Branch is not a store operation
            end
            // jal
            OPCODE_JAL: begin
                branch     = 0;
                jal        = 1;
                alu_src1    = 1; // JAL uses PC as source 1
                alu_src2    = 0; // JAL uses immediate value
                alu_op     = 2'b11;
                rs1_used  = 0; // JAL does not use rs1
                rs2_used  = 0; // JAL does not use rs2
                load       = 0; // JAL is not a load operation
                store      = 0; // JAL is not a store operation
            end          
            // default case: treat as NOP (do nothing)
            default: begin
                branch     = 0;
                jal        = 0;
                alu_src1    = 0; // NOP does not use rs1
                alu_src2    = 0; // NOP does not use rs2
                alu_op     = 2'b00;
                rs1_used  = 0; // NOP does not use rs1
                rs2_used  = 0; // NOP does not use rs2
                load       = 0; // NOP is not a load operation
                store      = 0; // NOP is not a store operation
            end
        endcase
    end



    

endmodule
