// ======================================
// reservation_station.sv -  Reservation Station Scheduler Module
// ======================================
`include "structs.svh"



module reservation_station (
    input logic clk_i,
    input logic reset_i,
    input logic recover_en,
    input logic rss2rs_valid,
    input rs_scheduler_s packed_rs_entry,  // Packed reservation station entry

    input logic fu_ready, 

    input logic [7:0] rs_clear, // Clear enable for reservation stations one hot encoded

    input cdb_packed_s cdb_packed, // CDB packet containing the result of the instruction

    output logic rs_full, // RS full signal

    output logic rs2fu_valid,   // Output to Function Unit
    output rs2fu_s rs2fu_entry,   //to ROB
    output logic [1:0] rs_fu_type,

    output logic [3:0]  rob_tag,      
    output logic [2:0]  rs_tag,      // Reservation station tag
    output logic rs_alu_ctrl,

    input logic [2:0] cdb2rs_rs_tag,

    input logic ex_load,clear_load,
    input logic [31:0] load_addr,
    input logic [2:0] load_rs_tag,

    output  logic load_req_valid, // load queue have data to be processed
    output  logic [3:0] load_req_rob_addr,
    output  logic [31:0] load_req_addr
    
);  

    reservation_station_s rs_entry [7:0];  // 8 reservation stations
    logic [7:0] full_bits;
    logic [7:0] valid_bits;                // Valid bits for each RS entry
    logic [7:0] ready_bits;                 // Ready bits for each RS entry
    logic [3:0] insert_idx;

    logic [3:0] load_queue [7:0];   // load which addr ready 
    logic [2:0] load_index,load_cnt; // Index for the load queue

    logic [2:0] rs_tag_comb;

    logic rs2fu_flag;

    assign load_req_valid = load_cnt!=load_index;
    assign load_req_rob_addr = rs_entry[load_queue[load_index]].rob_tag; // ROB tag of the load request
    assign load_req_addr = rs_entry[load_queue[load_index]].load_addr; // Load address from the reservation station entry

    assign rs_full = (full_bits == 8'b11111111); // RS is full if all entries are valid

    assign rob_tag = rs_entry[cdb2rs_rs_tag].rob_tag; // Output the ROB tag from the selected RS entry
    assign rs_alu_ctrl = rs_entry[cdb2rs_rs_tag].alu_ctrl; // Output the ALU control signal from the selected RS entry

    always_comb begin
        insert_idx = 8;
        if (rss2rs_valid) begin
            for (int i = 0; i < 8; i++) begin
                if (!full_bits[i] && insert_idx == 8)
                    insert_idx = i;
            end
        end
    end

    // Insert entry from RS Scheduler and handle clear and CDB update
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            for (int i = 0; i < 8; i++) begin
                rs_entry[i].vj <= '0; // Reset VJ and VK values
                rs_entry[i].vk <= '0;
                rs_entry[i].qj <= -1; // Initialize qj and qk to -1
                rs_entry[i].qk <= -1;
                rs_entry[i].store_imm <= '0; // Reset store immediate value
                rs_entry[i].rob_tag <= '0; // Reset ROB tag
                rs_entry[i].alu_ctrl <= '0; // Reset ALU control signal
                rs_entry[i].fu_type <= '0; // Reset function unit type
                rs_entry[i].branch_type <= '0; // Reset branch type
                rs_entry[i].branch <= 0; // Reset branch flag
                rs_entry[i].load <= 0; // Reset load flag
                rs_entry[i].store <= 0; // Reset store flag
                rs_entry[i].load_addr <= '0; // Reset load address
                rs_entry[i].load_addr_valid <= 0; // Reset load address valid signal
                rs_entry[i].rs_tag <= i; // Set reservation station tag
            end
            full_bits <= 8'b0; // Reset full bits
            load_index <= 0;
            load_cnt <= 0;
            for (int i = 0; i < 8; i++) begin
                load_queue[i] <= '0; // Reset load queue
            end
        end else begin
            // Clear specified entries
            for (int i = 0; i < 8; i++) begin
                if (rs_clear[i]) begin
                    //if(!rs_entry[i].load) begin
                    rs_entry[i].vj <= '0; // Reset VJ and VK values
                    rs_entry[i].vk <= '0;
                    rs_entry[i].qj <= -1; // Initialize qj and qk to -1
                    rs_entry[i].qk <= -1;
                    rs_entry[i].store_imm <= '0; // Reset store immediate value
                    rs_entry[i].rob_tag <= '0; // Reset ROB tag
                    rs_entry[i].alu_ctrl <= '0; // Reset ALU control signal
                    rs_entry[i].fu_type <= '0; // Reset function unit type
                    rs_entry[i].branch_type <= '0; // Reset branch type
                    rs_entry[i].branch <= 0; // Reset branch flag
                    rs_entry[i].load <= 0; // Reset load flag
                    rs_entry[i].store <= 0; // Reset store flag
                    rs_entry[i].load_addr <= '0; // Reset load address
                    rs_entry[i].load_addr_valid <= 0; // Reset load address valid signal
                    rs_entry[i].rs_tag <= i; // Set reservation station tag
                    full_bits[i] <= 1'b0; // Clear the full bit for this entry
                    if (clear_load) begin
                        load_queue[load_index] <= 'd0; // Store the tag in the load queu
                        load_index <= load_index + 1; // Increment load index
                    end
                end
            end

            // Insert new entry
            if (rss2rs_valid) begin
                if (cdb_packed.cdb_valid) begin
                    if(cdb_packed.cdb_rob_tag == packed_rs_entry.qj) begin
                        rs_entry[insert_idx].vj <= cdb_packed.cdb_data; // Update VJ with CDB data
                        rs_entry[insert_idx].qj <= -1; // Clear QJ since we have the value
                    end
                    else begin
                        rs_entry[insert_idx].vj <= packed_rs_entry.vj; // Use the original VJ if no CDB match
                        rs_entry[insert_idx].qj <= packed_rs_entry.qj;
                    end

                    if(cdb_packed.cdb_rob_tag == packed_rs_entry.qk) begin
                        rs_entry[insert_idx].vk <= cdb_packed.cdb_data; // Update VJ with CDB data
                        rs_entry[insert_idx].qk <= -1; // Clear QJ since we have the value
                    end
                    else begin
                        rs_entry[insert_idx].vk <= packed_rs_entry.vk; // Use the original VK if no CDB match
                        rs_entry[insert_idx].qk <= packed_rs_entry.qk;
                    end
                end
                else begin
                    rs_entry[insert_idx].vj <= packed_rs_entry.vj; // Use the original VJ
                    rs_entry[insert_idx].vk <= packed_rs_entry.vk; // Use the original VK
                    rs_entry[insert_idx].qj <= packed_rs_entry.qj; // Use the original QJ
                    rs_entry[insert_idx].qk <= packed_rs_entry.qk; // Use the original QK
                end
                rs_entry[insert_idx].store_imm <= packed_rs_entry.store_imm; // Set store immediate value
                rs_entry[insert_idx].rob_tag  <= packed_rs_entry.rob_tag;
                rs_entry[insert_idx].alu_ctrl <= packed_rs_entry.alu_ctrl;
                rs_entry[insert_idx].fu_type  <= packed_rs_entry.fu_type;
                rs_entry[insert_idx].branch_type <= packed_rs_entry.branch_type;
                rs_entry[insert_idx].branch   <= packed_rs_entry.branch;
                rs_entry[insert_idx].load     <= packed_rs_entry.load;
                rs_entry[insert_idx].store    <= packed_rs_entry.store;
                rs_entry[insert_idx].rs_tag   <= insert_idx;
                full_bits[insert_idx] <= 1'b1; // Set the full bit for this entry
            end

            // Handle load request
            if (ex_load) begin
                rs_entry[load_rs_tag].load_addr <= load_addr; // Set the load address
                rs_entry[load_rs_tag].load_addr_valid <= 1'b1; // Mark load address as valid
                load_queue[load_cnt] <= load_rs_tag; // Store the ROB tag in the load queue
                load_cnt <= load_cnt + 1; // Increment load index
            end 

            // CDB broadcast update to resolve qj/qk
            for (int i = 0; i < 8; i++) begin
                if (valid_bits[i] && cdb_packed.cdb_valid ) begin
                    if (rs_entry[i].qj == cdb_packed.cdb_rob_tag) begin
                        rs_entry[i].vj <= cdb_packed.cdb_data;
                        rs_entry[i].qj <= -1;
                    end
                    if (rs_entry[i].qk == cdb_packed.cdb_rob_tag) begin
                        rs_entry[i].vk <= cdb_packed.cdb_data;
                        rs_entry[i].qk <= -1;
                    end
                end
            end
        end
    end

    always_comb begin
        ready_bits = '0;
        rs_fu_type = 0; // Default function unit type
        rs_tag_comb = 0; // Default reservation station tag
        for (int i = 0; i < 8; i++) begin
            if (valid_bits[i] && rs_entry[i].qj == -1 && rs_entry[i].qk == -1) begin
                ready_bits[i] = 1;
            end
        end
        // Step 2: pick ready entry based on FU priority
        pick_loop: for (int prior = 3; prior >= 0; prior--) begin
            for (int i = 0; i < 8; i++) begin
                if (ready_bits[i] && rs_entry[i].fu_type == prior) begin
                    rs_tag_comb = i; // Set the reservation station tag
                    rs_fu_type = rs_entry[i].fu_type;
                    disable pick_loop;
                end
            end
        end
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            rs_tag <= 0;
            rs2fu_entry <= rs2fu_s'('0); // Reset the output entry
            rs2fu_valid <= 0; // Default to not valid
            //rs2fu_flag <= 0; // Default to not ready
        end else begin       
            if (fu_ready && (ready_bits!=0) ) begin
                if(rs_entry[rs_tag_comb].store) begin
                    rs2fu_entry.vk <= rs_entry[rs_tag_comb].store_imm; // Set VK value
                    rs2fu_entry.store_data <= rs_entry[rs_tag_comb].vk; // Set store data from VJ
                end else begin
                    rs2fu_entry.vk <= rs_entry[rs_tag_comb].vk; // Set VK value
                    rs2fu_entry.store_data <= '0; // Default store data to 0 if not a store instruction
                end
                rs2fu_entry.vj <= rs_entry[rs_tag_comb].vj; // Set VJ value
                rs2fu_entry.rob_tag <= rs_entry[rs_tag_comb].rob_tag; // Set ROB tag
                rs2fu_entry.alu_ctrl <= rs_entry[rs_tag_comb].alu_ctrl; // Set ALU control signal
                rs2fu_entry.fu_type <= rs_entry[rs_tag_comb].fu_type; // Set function unit type
                rs2fu_entry.branch <= rs_entry[rs_tag_comb].branch; // Set branch flag
                rs2fu_entry.load <= rs_entry[rs_tag_comb].load; // Set load flag
                rs2fu_entry.store <= rs_entry[rs_tag_comb].store; // Set store flag
                rs2fu_entry.branch_type <= rs_entry[rs_tag_comb].branch_type; // Set branch type
                rs2fu_entry.rs_tag <= rs_tag_comb; // Set the reservation station tag in the output
                rs2fu_valid <= 1; // Mark the output as valid
                rs_tag <= rs_tag_comb; // Default tag
                //rs2fu_flag <= 1; // Mark the output as ready
            end
            else begin
                rs2fu_valid <= 0; // Not valid if not ready
               // rs2fu_flag <= 0; // Not ready
            end
        end
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            valid_bits <= 8'b0; // Reset valid bits
        end else begin
            if (rss2rs_valid) begin
                valid_bits[insert_idx] <= 1'b1; // Set the valid bit for the inserted entry
            end
            if (fu_ready && (ready_bits!=0) ) begin
                valid_bits[rs_tag_comb] <= 1'b0; // Clear the valid bit for the issued entry
            end
        end
    end


     



endmodule