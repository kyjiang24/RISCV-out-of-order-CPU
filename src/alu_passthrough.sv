module alu_passthrough (
    input  logic clk_i,
    input  logic reset_i,

    // Handshake interface
    input  logic alu_valid,                // Input data is valid
    output logic alu_ready,                // Ready to accept input
    input  logic [31:0] alu_reg_in,  // Input data

    output logic alu_valid_o,              // Output data is valid
    input  logic yumi_i,                   // Downstream module consumed data
    output logic [31:0] alu_reg_out  // Output data
);

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            alu_reg_out <= 32'b0;
            alu_valid_o <= 0;
        end else if (alu_valid) begin
            alu_reg_out <= alu_reg_in;
            alu_valid_o <= 1;
        end else if (yumi_i) begin
            alu_valid_o <= 0;
        end else if (alu_valid_o && !yumi_i) begin
            alu_reg_out <= alu_reg_out; // Hold the current value
            alu_valid_o <= 1; // Keep valid state until consumed
        end else begin
            alu_valid_o <= 0; // Hold the valid state
        end
    end


    assign alu_ready = (alu_valid_o && !yumi_i) ? 0 : 1;


endmodule
