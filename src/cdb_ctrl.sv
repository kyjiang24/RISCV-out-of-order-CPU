`include "structs.svh"



module cdb_ctrl(
    input logic clk_i, reset_i,
    input logic [3:0] cdb_rob_tag, // Reorder buffer tag of the instruction writing to it
    input logic [31:0] dm_data, alu_reg_data, mul_final_o, div_final_o,
    input logic datamem_valid, alu_valid, mul_valid, div_valid, // Valid signals for different operations
    input logic ex_branch,branch_taken,ex_load, // Branch execution and branch taken signals
    input logic [31:0] store_data,

    output cdb_packed_s packed_cdb_packet, // Packed CDB packet
    output logic [3:0] cdb_yumi
    
);


    always_comb begin
        if (div_valid) begin
            packed_cdb_packet.cdb_valid = 1;
            packed_cdb_packet.cdb_rob_tag = cdb_rob_tag;
            packed_cdb_packet.cdb_data = div_final_o;
            packed_cdb_packet.cdb_store_data = 32'b0; // Store data for divider
            cdb_yumi = 4'b0001; // divider
        end else if (mul_valid) begin
            packed_cdb_packet.cdb_valid = 1;
            packed_cdb_packet.cdb_rob_tag = cdb_rob_tag;
            packed_cdb_packet.cdb_data = mul_final_o;
            packed_cdb_packet.cdb_store_data = 32'b0; // Store data for divider
            cdb_yumi = 4'b0010; // multiplier
        end else if (datamem_valid) begin
            packed_cdb_packet.cdb_valid = 1;
            packed_cdb_packet.cdb_rob_tag = cdb_rob_tag;
            packed_cdb_packet.cdb_data = dm_data;
            packed_cdb_packet.cdb_store_data = 32'b0; // Store data for divider
            cdb_yumi = 4'b0100; // datamem
        end else if (alu_valid) begin
            if(ex_branch) begin
                // If it's a branch instruction, we need to handle it differently
                packed_cdb_packet.cdb_valid = 1;
                packed_cdb_packet.cdb_rob_tag = cdb_rob_tag;
                packed_cdb_packet.cdb_data = branch_taken; // Use ALU data for branch
                packed_cdb_packet.cdb_store_data = 32'b0; // Store data for divider
                cdb_yumi <= 4'b1000; // alu
            end else if (ex_load) begin
                packed_cdb_packet.cdb_valid = 0;
                packed_cdb_packet.cdb_rob_tag = 'd0;
                packed_cdb_packet.cdb_data = 'd0;
                packed_cdb_packet.cdb_store_data = 'd0; // Store data for ALU
                cdb_yumi <= 4'b0000; // alu
            end else begin
                // For non-branch ALU operations
                packed_cdb_packet.cdb_valid = 1;
                packed_cdb_packet.cdb_rob_tag = cdb_rob_tag;
                packed_cdb_packet.cdb_data = alu_reg_data;
                packed_cdb_packet.cdb_store_data = store_data; // Store data for ALU
                cdb_yumi <= 4'b1000; // alu
            end
        end else begin
            packed_cdb_packet.cdb_valid = 0;
            packed_cdb_packet.cdb_rob_tag = 4'b0000; // Reset ROB tag
            packed_cdb_packet.cdb_data = 32'b0; // Reset data
            packed_cdb_packet.cdb_store_data = 32'b0; // Store data for divider
            cdb_yumi = 'd0;
        end
    end


endmodule
