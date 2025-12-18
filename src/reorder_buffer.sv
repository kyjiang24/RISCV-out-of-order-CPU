// ======================================
// reorder_buffer.sv -  Reorder Buffer Module
// ======================================

`include "structs.svh"



module reorder_buffer (
    input  logic        clk_i, // Clock signal
    input  logic        reset_i, // Active-high synchronous reset

    input  logic [31:0] ifis_pc,
    input  logic    ifis_b_pred_taken, // Branch prediction taken signal
    input  logic [31:0] ifis_b_pred_target, // Branch prediction target address 

    input  logic [4:0]  issue_dst, // Destination register for issue
    input  logic    issue_valid, // Valid signal for issue
    input  logic branch,
    input  logic store,
    input  logic [31:0] store_data,
    output  logic [3:0]  issue_rob_tag, // ROB tag for issue
    

    input cdb_packed_s cdb_packed, // CDB packet containing the result of the instruction

    output logic [31:0] cdb_dest,
    output logic cdb_store,

    output logic commit_valid, // Valid signal for commit
    output logic [3:0] commit_rob_tag, // ROB tag for commit
    output logic [31:0] commit_value, // Value to commit
    output logic [31:0] commit_dst,
    output logic commit_store,

    output logic  rob_full, // Full status of the ROB
    output logic recover_en, // Enable signal for recovery (if branch misprediction)
    output logic [31:0] recover_pc, // PC to recover to on branch misprediction

    output rob_head_s rob_head, // Expose ROB head information

    input logic [3:0] packed_rs1_rob_tag, // Packed ROB tag for RS1
    input logic [3:0] packed_rs2_rob_tag, // Packed ROB tag for RS2
    output logic [31:0] packed_rs1_value, // Value from RS1
    output logic [31:0] packed_rs2_value // Value from RS2
);

    rob_s rob [15:0]; // 16 entries in the reorder buffer

    logic [3:0] head, tail;
    logic full_flag;

    assign packed_rs1_value = rob[packed_rs1_rob_tag].value; // Value from RS1
    assign packed_rs2_value = rob[packed_rs2_rob_tag].value; // Value from RS2

    // assign rob_full = (head == tail) && full_flag;
    assign rob_full = full_flag;

    // assign rob_head.ready = rob[head].ready;
    // assign rob_head.value = rob[head].value;
    // assign rob_head.addr = rob[head].dest_reg; // Address to write to
    // assign rob_head.rob_addr = head; // Address value 0-15 of head entry (implemented with circular FIFO)
    // assign rob_head.store = rob[head].store; // Is the head entry a store instruction?

    assign issue_rob_tag = tail; // Output the ROB tag for the issued instruction
    
    assign cdb_dest = rob[cdb_packed.cdb_rob_tag].dest_reg; // Output the ROB tag from CDB
    assign cdb_store = rob[cdb_packed.cdb_rob_tag].store;
    
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            rob_head <=  rob_head_s'('0); // Reset ROB head information
        end else begin
            // Update ROB head information
            rob_head.ready <= rob[head].ready;
            rob_head.value <= rob[head].value;
            rob_head.addr <= rob[head].dest_reg; // Address to write to
            rob_head.rob_addr <= head; // Address value 0-15 of head entry (implemented with circular FIFO)
            rob_head.store <= rob[head].store; // Is the head entry a store instruction?
            rob_head.branch <= rob[head].branch; // Is the head entry a branch instruction?
            rob_head.store_data <= rob[head].store_data; // Store data if applicable
            rob_head.branch_taken <= rob[head].branch_predict_taken; // Is the branch taken?
            rob_head.branch_predict_taken <= rob[head].branch_predict_taken; // Is the branch prediction taken?
            rob_head.branch_target <= rob[head].branch_target; // Target address for branch instruction
        end
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            tail <= 0;
        end else if (rob[head].branch && rob[head].ready && rob[head].value != rob[head].branch_predict_taken) begin
            tail <= 0;
        end else if (issue_valid && !rob_full) begin
            tail <= tail + 1;
        end
    end
    
    
    // Issue new instruction into ROB
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            head <= 0;
            full_flag <= 0;
            foreach (rob[i]) begin
                rob[i] <= rob_s'('d0);
            end
            //rob_store_ready <= 0;
            //rob_store_data <= 32'b0;
            commit_valid <= 0;
            recover_en <= 0;
            recover_pc <= 32'b0;
        end else begin
            recover_en <= 0;
            recover_pc <= 32'b0;
            //rob_store_ready <= 0;
            commit_valid <= 0;
            // Commit
            if (rob[head].busy && rob[head].ready) begin
                // Branch recovery logic
                if (rob[head].branch && rob[head].value != rob[head].branch_predict_taken) begin
                    recover_en <= 1;
                    recover_pc <= rob[head].value ? rob[head].branch_target : rob[head].pc + 4;
                    foreach (rob[i]) begin
                        rob[i] <= rob_s'('d0);
                    end
                    head <= 0;
                    full_flag <= 0;
                    commit_valid <= 1;
                    commit_rob_tag <= 0;
                    commit_store <= 0;
                    commit_value <= 0;
                    commit_dst <= 0;
                    //rob_store_ready <= 0;
                end else if (rob[head].store) begin
                    //rob_store_ready <= 1;
                    commit_valid <= 1;
                    commit_rob_tag <= head;
                    commit_store <= rob[head].store;
                    commit_value <= rob[head].store_data; // Store data to commit
                    commit_dst <= rob[head].value;
                    //rob_store_addr <= rob[head].value[4:0];
                    head <= head + 1;
                end else begin
                    head <= head + 1;
                    rob[head].busy <= 0;
                    full_flag <= 0;
                    commit_valid <= 1;
                    commit_rob_tag <= head;
                    commit_store <= rob[head].store;
                    commit_value <= rob[head].value;
                    commit_dst <= rob[head].dest_reg;
                end
            end

            // Writeback from CDB
            if (cdb_packed.cdb_valid && rob[cdb_packed.cdb_rob_tag].busy) begin
                rob[cdb_packed.cdb_rob_tag].value <= cdb_packed.cdb_data;
                rob[cdb_packed.cdb_rob_tag].store_data <= cdb_packed.cdb_store_data; // Store data if applicable
                rob[cdb_packed.cdb_rob_tag].ready <= 1;
            end

            // Issue new entry
            if (issue_valid && !rob_full) begin
                rob[tail].busy <= 1;
                rob[tail].ready <= 0;
                rob[tail].dest_reg <= issue_dst;
                rob[tail].branch <= branch;
                rob[tail].store <= store;
                rob[tail].store_data <= 'd0;
                rob[tail].pc <= ifis_pc;
                rob[tail].branch_predict_taken <= ifis_b_pred_taken;
                rob[tail].branch_target <= ifis_b_pred_target;
                rob[tail].value <= 32'b0; // Initialize value to zero
                
                if ((tail + 1) == head) full_flag <= 1;
            end
        end
    end



endmodule