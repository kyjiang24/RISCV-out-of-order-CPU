module fifo #(
    parameter data_width_p = 4,
    parameter els_p = 16
) (
    input logic clk_i,
    input logic reset_i,

    input logic wr_i,
    input logic [data_width_p-1:0] wr_data_i,
    output logic full_o,

    input logic rd_i,
    output logic [data_width_p-1:0] rd_data_o,
    output logic empty_o
);

    logic [$clog2(els_p):0] count;
    logic [$clog2(els_p)-1:0] rd_ptr, wr_ptr;
    logic [data_width_p-1:0] mem [els_p-1:0];

    assign full_o = (count == els_p);
    assign empty_o = (count == 0);
    assign rd_data_o = mem[rd_ptr]; // <= lookahead enabled

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            count <= 0;
            rd_ptr <= 0;
            wr_ptr <= 0;
        end else begin
            if (wr_i & ~full_o) begin
                mem[wr_ptr] <= wr_data_i;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end

            if (rd_i & ~empty_o) begin
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end
        end
    end

endmodule
