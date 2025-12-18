module gshare_unit (
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] pc,              // Current PC
    input  logic        branch_valid,    // Commit-stage branch instruction valid
    input  logic        branch_taken,    // Actual result of the branch (1 = taken)
    
    output logic        branch_predict_taken   // Predicted result
);

    // --- internal state ---
    logic [1:0] prediction_table [0:1023];  // 2-bit saturating counters
    logic [9:0] ghr;                        // 10-bit global history register
    logic [1:0] prediction_value;
    logic [9:0]  index;
    // --- index: XOR of PC and GHR ---
    assign index = pc[9:0] ^ ghr;

    // --- synchronous read of prediction_table ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            prediction_value <= 2'b10;  // weakly not taken
        else
            prediction_value <= prediction_table[index];
    end

    // --- predict taken if MSB of saturating counter is 1 ---
    assign branch_predict_taken = prediction_value[1];

    // --- update logic on valid branch ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ghr <= 10'b0;
            foreach (prediction_table[i])
                prediction_table[i] <= 2'b10; // weakly not taken
        end else if (branch_valid) begin
            // Update prediction table entry
            case (prediction_table[index])
                2'b00: prediction_table[index] <= branch_taken ? 2'b01 : 2'b00;
                2'b01: prediction_table[index] <= branch_taken ? 2'b10 : 2'b00;
                2'b10: prediction_table[index] <= branch_taken ? 2'b11 : 2'b01;
                2'b11: prediction_table[index] <= branch_taken ? 2'b11 : 2'b10;
            endcase

            // Shift in new branch result to GHR
            ghr <= {ghr[8:0], branch_taken};
        end
    end

endmodule
