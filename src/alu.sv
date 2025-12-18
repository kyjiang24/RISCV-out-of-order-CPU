module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic    cntrl_i, //0: add, 1: sub 
    output logic [31:0] data_o,
    output logic        neg_o,
    output logic        zero_o
);

    parameter alu_add  = 1'b0,
			  alu_sub  = 1'b1;		  
		  
    logic [31:0] result;
    logic [31:0] sum, diff;

    always_comb begin
        case (cntrl_i)
            alu_add: begin // ADD
                sum = a_i + b_i;
                result = sum[31:0];
            end
            alu_sub: begin // SUB
                diff = a_i - b_i;
                result = diff[31:0];
            end
			
            default: result = 32'd0;
        endcase
    end

    // Assign outputs
    assign data_o = result;
    assign zero_o = (result == 0);
    assign neg_o  = result[31];

endmodule