`include "structs.svh"

module fu_ctrl(
    input logic clk_i, reset_i,recover_en,
    input logic rs2fu_valid, // Reservation station to function unit valid signal
    input rs2fu_s packed_rsfu_entry, // Packed reservation station 
    input logic [1:0] rs_fu_type,
    input logic mul_ready, div_ready,alu_ready,
    input logic mul_valid_o, div_valid_o,

    output logic mul_valid, div_valid,alu_valid, //FU ready to accept new instructions

    output logic fu_ready, // Function unit ready signal
    output logic alu_ctrl, // ALU control signal
    output logic [1:0] fu_type, // Function unit type (0: nah, 1: ALU, 2: Multiply, 3: Divide)
    output logic [1:0] branch_type, // Branch type (0: None, 1: BEQ, 2: BNE, 3: BLT)
    output logic is_store, is_load, is_branch,
    output logic [31:0] store_data, // Data for store instruction
    output logic [31:0] fu_vj, fu_vk, // Values for VJ and VK
    output logic [2:0] fu_rs_tag // Reservation station tag
);

    logic [1:0] rs_fu_type_reg;

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            rs_fu_type_reg <= 2'b00; // Reset to default value
        //end else if(mul_valid_o || div_valid_o) begin
        //    rs_fu_type_reg <= 2'b00; // Reset to default value
        end else if(mul_valid_o && rs_fu_type== 2'b10) begin
            rs_fu_type_reg <= 2'b00;
        end else if(div_valid_o && rs_fu_type== 2'b11) begin
            rs_fu_type_reg <= 2'b00;
        end else begin
            rs_fu_type_reg <= rs_fu_type; // Update function unit type from packed RS entry
        end
    end

    always_comb begin
        // Default values
        fu_ready = 0;
        case (rs_fu_type)
            2'b01:  begin // ALU
                if(alu_ready) begin
                    fu_ready = 1;
                end else begin
                    fu_ready = 0;
                end 
            end
            2'b10: begin
                if(mul_ready && rs_fu_type_reg!=2) begin
                    fu_ready = 1;
                end else begin
                    fu_ready = 0;
                end // Multiply
            end
            2'b11: begin
                // Divide
                if(div_ready && rs_fu_type_reg!=3) begin
                    fu_ready = 1;
                end else begin
                    fu_ready = 0;
                end // Multiply
            end
            default: begin
                // Load/Store or no operation
                fu_ready = 0; // Not ready for Load/Store or no operation
            end
        endcase
    end


    // Function unit control logic
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            alu_ctrl <= 0; // Default ALU control signal
            branch_type <= 2'b00; // Default branch type (None)
            alu_valid <= 0;
            mul_valid <= 0;
            div_valid <= 0;
            is_store <= 0;
            is_load <= 0; // Reset load flag
            is_branch <= 0; // Reset branch flag
            store_data <= 0; // Reset store data
            fu_vj <= 0;
            fu_vk <= 0;
            fu_rs_tag <= 0; // Reset reservation station tag
        end else if (rs2fu_valid) begin
            if (alu_ready && rs_fu_type_reg == 2'b01) begin
                // ALU operation
                alu_ctrl <= packed_rsfu_entry.alu_ctrl; // Set ALU control signal
                fu_type <= 2'b01; // Set function unit type to ALU
                branch_type <= packed_rsfu_entry.branch_type; // Set branch type
                alu_valid <= 1; // Ready to send to ALU
                mul_valid <= 0; // Reset multiply valid
                div_valid <= 0; // Reset divide valid
                is_store <= packed_rsfu_entry.store; // Check if it's a store operation
                is_load <= packed_rsfu_entry.load; // Check if it's a load operation
                is_branch <= packed_rsfu_entry.branch; // Check if it's a branch operation
                fu_vj <= packed_rsfu_entry.vj; // Set VJ value
                fu_vk <= packed_rsfu_entry.vk; // Set VK value
                fu_rs_tag <= packed_rsfu_entry.rs_tag; // Set reservation station tag
                store_data <= packed_rsfu_entry.store_data; // Set store data
            end else if (mul_ready && rs_fu_type_reg == 2'b10) begin
                // Multiply operation
                alu_ctrl <= 3'b000; // No specific control for multiply, handled in booth_mult module
                fu_type <= 2'b10; // Set function unit type to Multiply
                branch_type <= 2'b00; // No branch type for multiply
                alu_valid <= 0; // Reset ALU valid
                mul_valid <= 1; // Ready to send to Multiply FU
                div_valid <= 0; // Reset divide valid
                is_store <= packed_rsfu_entry.store; // Check if it's a store operation
                is_load <= packed_rsfu_entry.load; // Check if it's a load operation
                is_branch <= 0; // No branch for multiply
                fu_vj <= packed_rsfu_entry.vj; // Set VJ value
                fu_vk <= packed_rsfu_entry.vk; // Set VK value
                fu_rs_tag <= packed_rsfu_entry.rs_tag; // Set reservation station tag
                store_data <= packed_rsfu_entry.store_data; // Set store data
            end else if (div_ready && rs_fu_type_reg == 2'b11) begin
                // Divide operation
                alu_ctrl <= 3'b000; // No specific control for divide, handled in separate module
                fu_type <= 2'b11; // Set function unit type to Divide
                branch_type <= 2'b00; // No branch type for divide
                alu_valid <= 0; // Reset ALU valid
                mul_valid <= 0; // Reset multiply valid
                div_valid <= 1; // Ready to send to Divide FU
                is_store <= packed_rsfu_entry.store; // Check if it's a store operation
                is_load <= packed_rsfu_entry.load; // Check if it's a load operation
                is_branch <= 0; // No branch for divide
                fu_vj <= packed_rsfu_entry.vj; // Set VJ value
                fu_vk <= packed_rsfu_entry.vk; // Set VK value
                fu_rs_tag <= packed_rsfu_entry.rs_tag; // Set reservation station tag
                store_data <= packed_rsfu_entry.store_data; // Set store data
            end else begin
                // No valid operation, reset outputs
                alu_ctrl <= 3'b000; // Default ALU control signal
                fu_type <= 2'b00; // Default function unit type (Load/Store)
                branch_type <= 2'b00; // Default branch type (None)
                alu_valid <= 0;
                mul_valid <= 0;
                div_valid <= 0;
                is_store <= 0;
                is_load <= 0; // Reset load flag
                fu_vj <= 0;
                fu_vk <= 0;
                fu_rs_tag <= packed_rsfu_entry.rs_tag; // Set reservation station tag
                store_data <= packed_rsfu_entry.store_data; // Set store data
            end
        end
        else begin
            // No valid RS to FU entry, reset outputs
            alu_valid <= 0;
            mul_valid <= 0;
            div_valid <= 0;
            is_store <= 0;
            is_load <= 0; // Reset load flag
            fu_vj <= 0;
            fu_vk <= 0;
            fu_rs_tag <= 0;
        end
    end

endmodule