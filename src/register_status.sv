/*
    Register file status registers storing whether each register has an instruction
    in the ROB waiting to write on it, and if so which instruction.

    Inputs:
        - reset_i: reset
        - clk_i: clk
        - issue_rd_addr1_i: first source register
        - issue_rd_addr2_i: second source register
        - issue_wr_en_i: write to set new status
        - issue_wr_addr_i: register address to set status of (Rd)
        - issue_reorder_addr_i: reorder buffer number of issue instruction
        - commit_wr_en_i: check and free commit_wr_addr register if
            RegStat[commit_wr_addr] = reorder_addr
        - commit_wr_addr_i: register address to check and potentially free
        - commit_reorder_addr_i: reorder address of commited instruction

    Outputs:
        - issue_rd_data1_o: data from first source register
        - issue_rd_data2_o: data from second source register
*/

`include "structs.svh"

module register_status (
    input logic clk_i, reset_i,recover_en, issue_valid, commit_valid,cdb_valid,
    input logic [4:0] rs1, rs2, issue_dst, commit_dst,cdb_dest,
    input logic [3:0] issue_rob_tag, commit_rob_tag, cdb_rob_tag,
    input logic cdb_store,commit_store,
    output register_status_s packed_rs1, packed_rs2  
);
    // Register status array
    register_status_s regstat [31:0];  // 32 registers, each with a status entry
    

    // Update and query regstat status
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            // On reset, clear all register status
            foreach (regstat[i]) begin
                regstat[i].busy   <= 0;
                regstat[i].re_busy <= 0;
                regstat[i].rob_tag <= 0;
            end
        end else begin
            // On commit, clear busy if the ROB tag matches
            if (commit_valid) begin
                if (regstat[commit_dst].rob_tag == commit_rob_tag && !commit_store) begin
                    regstat[commit_dst].busy <= 0;
                end
            end

            if (cdb_valid) begin
                // If CDB is valid, check if the ROB tag matches
                if (regstat[cdb_dest].rob_tag == cdb_rob_tag && !cdb_store) begin
                    regstat[cdb_dest].re_busy <= 0; // Clear busy status
                end
            end
            // On issue, set busy and update ROB tag
            if (issue_valid && issue_dst!='d0) begin
                regstat[issue_dst].busy    <= 1;
                regstat[issue_dst].re_busy <= 1; // Set re_busy to indicate reservation station usage
                regstat[issue_dst].rob_tag <= issue_rob_tag;
            end
        end
    end

    assign packed_rs1 = regstat[rs1];
    assign packed_rs2 = regstat[rs2];




endmodule
