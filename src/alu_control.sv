// ======================================
// alu_control.sv - ALU Control Logic Module 
// ======================================
module alu_control (
    input  logic [1:0]  alu_op,     // from control.sv
    input  logic [2:0]  funct3,     // bits [14:12] of instruction
    input  logic [6:0]  funct7,     // bits [31:25] of instruction
    output logic [2:0]  alu_ctrl,    // 1-bit control signal (ALU 0:add,1:sub; MUL 0:mul,1:mulh; DIV 0:div,1:rem )
    output logic [1:0]  fu_type, // Function unit type (0: Nah, 1: ALU, 2: Multiply, 3:Divide)
    output logic [1:0]  branch_type // Branch type (0: None, 1: BEQ, 2: BNE, 3: BLT)
);

    always_comb begin	
        case (alu_op)
            2'b11: begin // I-type load/store jal
                alu_ctrl = 1'b0;  //add
                fu_type = 2'd1; // ALU function unit
                branch_type = 2'b00; // No branch
            end
            2'b01: begin // branch
                alu_ctrl = 1'b1;  //sub
                fu_type = 2'd1; // ALU function unit
                case (funct3) 
                    3'b000: branch_type = 2'b01; // BEQ
                    3'b001: branch_type = 2'b10; // BNE
                    3'b100: branch_type = 2'b11; // BLT
                    default: branch_type = 2'b00; // No branch
                endcase
            end
            2'b10: begin
                // R-type
				case (funct3)
                    3'b000: begin
                        case (funct7)
                            7'b0000000: begin // add
                                alu_ctrl = 1'b0; // add
                                fu_type = 2'd1; 
                            end
                            7'b0100000: begin // sub
                                alu_ctrl = 1'b1; // sub
                                fu_type = 2'd1;
                            end
                            7'b0000001: begin // mul
                                alu_ctrl = 1'b0;  //mul
                                fu_type =  2'd2; // Multiply function unit
                            end

                            default: begin
                                alu_ctrl = 1'b0;
                                fu_type = 2'd0; // ALU function unit
                            end
                        endcase
                    end
                    3'b001: begin //mulh
                        alu_ctrl = (funct7 == 7'b0000001) ? 1'b1 : 1'b0;//mulh
                        fu_type = (funct7 == 7'b0000001) ? 2'd2 : 2'd1; // Multiply function unit
                    end
                    3'b100: begin //div
                        alu_ctrl = 1'b0; //div
                        fu_type = (funct7 == 7'b0000001) ? 2'd3 : 2'd1; // Divide function unit
                    end
                    3'b111: begin //remu
                        alu_ctrl = (funct7 == 7'b0000001) ? 1'b1 : 1'b0; //remu
                        fu_type = (funct7 == 7'b0000001) ? 2'd3 : 2'd1; // Divide function unit
                    end
                    default: begin
                        alu_ctrl = 1'b0;
                        fu_type = 2'd0; // ALU function unit
                    end
                endcase
                branch_type = 2'b00; // No branch
            end
            default: begin
                alu_ctrl = 1'b0;
                fu_type = 2'd0; // Default to ALU function unit
                branch_type = 2'b00; //No branch
            end
        endcase
		
		//$display("[ALU_CTRL] alu_op = %b, funct3 = %b, funct7 = %b → alu_ctrl = %b",
        //      alu_op, funct3, funct7, alu_ctrl);
		
    end
	
	
endmodule