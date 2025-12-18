module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        pc_write_en,
    input  logic [31:0] pc_in,
    output logic [31:0] pc_out
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc_out <= 32'h0000_0000;
        else if (pc_write_en)
            pc_out <= pc_in;
        // else, hold the current value
    end

endmodule
