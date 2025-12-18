`include "structs.svh"

module rs_scheduler (
    input logic clk_i, reset_i,
    input register_status_s packed_rs1, packed_rs2, // Packed register status entries
    input logic [3:0] issue_rob_tag, 
    input logic [31:0] data1, data2,store_imm,   //output from mux(input: rs1/pc, rs2/imm_out)
    input logic rob_full, // ROB full signal
    input logic [2:0] alu_ctrl,
    input logic [1:0] fu_type, // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    input logic [1:0]  branch_type,
    input logic ctrl_branch, ctrl_rs1_used, ctrl_rs2_used, ctrl_load, ctrl_store,
    input logic rs_full,
    input [31:0] packed_rs1_value, packed_rs2_value, // Values from packed register status entries

    output logic rss_issue_valid,    
   
    output rs_scheduler_s packed_rs_entry  // Packed reservation station entry
);

    // Reservation station array
    rs_scheduler_s rs_array;  // 8 reservation stations

    assign rss_issue_valid = (fu_type!=0) && !rs_full; // Forward the valid signal to the output
    
    always_comb begin
        // Default values for packed RS entry
        packed_rs_entry.vj = data1; // Set VJ to data1
        packed_rs_entry.vk = data2; // Set VK to data2
        packed_rs_entry.qj = (ctrl_rs1_used && packed_rs1.busy) ? packed_rs1.rob_tag : -1;
        packed_rs_entry.qk = (ctrl_rs2_used && packed_rs2.busy) ? packed_rs2.rob_tag : -1;
        packed_rs_entry.store_imm = store_imm; // Set store immediate value
        packed_rs_entry.rob_tag = issue_rob_tag; // Set ROB tag
        packed_rs_entry.alu_ctrl = alu_ctrl;
        packed_rs_entry.fu_type = fu_type;
        packed_rs_entry.branch_type = branch_type; // Set branch type
        packed_rs_entry.branch = ctrl_branch;
        packed_rs_entry.load = ctrl_load;
        packed_rs_entry.store = ctrl_store;

        if (packed_rs1.busy && !packed_rs1.re_busy && ctrl_rs1_used) begin
            packed_rs_entry.vj = packed_rs1_value;
            packed_rs_entry.qj = -1; // Clear QJ since we have the value
        end
        if (packed_rs2.busy && !packed_rs2.re_busy && ctrl_rs2_used) begin
            packed_rs_entry.vk = packed_rs2_value;
            packed_rs_entry.qk = -1; // Clear QK since we have the value
        end
    end
    
    



endmodule