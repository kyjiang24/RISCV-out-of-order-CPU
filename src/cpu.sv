/*
    Out-of-Order RISC-V CPU implementing Tomasulo's Algorithm for dynamic scheduling.  
    Supports a subset of the RV32IM instruction set:  
    add, sub, addi, mul, mulh, div, rem, lw, sw, bne, beq, blt, bge, jal.        
*/

`include "structs.svh"

`include "macros.svh"

module cpu (
    input logic clk_i, reset_i
);

    /*
        Logic Declarations
    */
/* ------------------------------ IF ------------------------------ */

    // Gshare Unit
    logic        branch_predict_taken;          

    //bp_se
    logic        is_branch;
    logic [31:0] branch_target;

    // Instruction Memory
    logic		[31:0]	address;
    logic		[31:0]	instr;

    // Program Counter
    logic [31:0] pc; // program counter output
    logic [31:0] pc_reg;
    logic pc_write_en; // program counter write enable

    //Jump and PC recover
    logic [31:0] jump_target; // Jump target address
    logic [31:0] pc_recover; // PC recovery address
    logic recover_en; // PC recovery enable


    // IFIS Pipeline Registers
    logic [31:0] ifis_pc; // Program counter in IF stage
    logic [31:0] ifis_instr; // Instruction fetched in IF stage
    logic ifis_branch_predict_taken; // Branch prediction taken in IF stage
    logic [31:0] ifis_branch_target; // Branch target in IF stage

    /* ------------------------------ IS ------------------------------ */
    // Instruction Decoder
    logic [4:0] rs1, rs2, rd; // Source and destination registers
    logic [6:0] opcode; // Opcode of the instruction
    logic [2:0] func3; // Function 3 field
    logic [6:0] func7; // Function 7 field  

    // Register File
    logic wr_en_i;
    logic [4:0] wr_addr_i; // Write address
    logic [31:0] wr_data_i; // Write data
    logic [31:0] rs1_data; // Read data 1 output
    logic [31:0] rs2_data; // Read data 2 output

    //sign extension
    logic [31:0] imm_out,store_imm; // Immediate output after sign extension

    //control signals
    logic ctrl_branch; // Branch control signal
    logic ctrl_jal; // JAL control signal
    logic ctrl_alu_src1; // ALU source 1 control signal (0: rs1, 1: pc)
    logic ctrl_alu_src2; // ALU source 2 control signal (0: rs2, 1: imm)
    logic [1:0] ctrl_alu_op; // ALU operation control signal
    logic ctrl_rs1_used; // RS1 used control signal
    logic ctrl_rs2_used; // RS2 used control signal
    logic ctrl_load; // Load control signal
    logic ctrl_store; // Store control signal

    //alu control signals
    logic [2:0] is_alu_ctrl; // ALU control signal
    logic [1:0] is_fu_type; // Function unit type (0: Nah, 1: ALU, 2: Multiply, 3: Divide)
    logic [1:0]  is_branch_type; // Branch type (0: None, 1: BEQ, 2: BNE, 3: BLT)

    //register status
    register_status_s packed_rs1,packed_rs2; // Register status array

    //rs_scheduler
    logic [31:0] rss_data1; 
    logic [31:0] rss_data2;
    logic rss_issue_valid; // Issue enable signal for RS scheduler
    
    rs_scheduler_s packed_rs_entry; // Packed RS entry for RS scheduler

    //reorder buffer
    logic [3:0] issue_rob_tag; // ROB tag for issue
    logic rob_commit_valid; // Valid signal for commit
    logic [31:0] rob_commit_data; // Value to commit
    logic [31:0] rob_commit_dst; // Destination register for commit
    logic [3:0] commit_rob_tag; // Reservation station tag
    logic commit_store;
    logic rob_full; // Full status of the ROB
    logic [4:0]rob_store_addr; // Address for store operation in ROB
    logic rob_store_ready; // Store ready signal in ROB
    logic [31:0] rob_store_value; // Value to store in ROB
    logic [31:0] packed_rs1_value; // Value from RS1
    logic [31:0] packed_rs2_value; // Value from RS2
    rob_head_s rob_head;

    // reservation station
    logic rs_full;
    logic rs2fu_valid; // Output to functional unit
    rs2fu_s rs2fu_entry; // Reservation station entry to functional unit
    logic [3:0]  rs_rob_tag;
    logic [1:0]  rs_fu_type; // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    logic [2:0]  rs_tag; // Reservation station tag
    logic rs_alu_ctrl; // ALU control signal in reservation station
    logic [2:0] cdb2rs_rs_tag;
    logic [31:0] cdb_dest;
    logic [31:0]  rs_load_addr; // Load address
    logic [2:0]  rs_load_rs_tag; // Load reservation station tag

    logic load_req_valid,clear_load;
    logic [3:0] load_req_rob_addr;
    logic [31:0] load_req_addr;

    // idea enqueue store upon issue
    logic datamem_fifo_dequeue, datamem_fifo_enqueue, datamem_fifo_full;
    logic [3:0] datamem_fifo_data_lo;

    // avoid incorrect comparison by taking distance from current head index
    logic load_before_store, load_req_yumi;
    logic [3:0] load_req_head_dist, store_req_head_dist;

    /* ------------------------------ EX ------------------------------ */
    
    // Functional Unit ctrl
    logic fu_ready; // Functional unit ready signal
    logic  ex_alu_ctrl; // ALU control signal
    logic [1:0] ex_fu_type; // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    logic [1:0] ex_branch_type; // Branch type (0: None, 1: BEQ, 2: BNE, 3: BLT)

    logic ex_store; // Store operation flag
    logic ex_load,ex_load_dly1,load_addr_valid; // Load operation flag
    logic ex_branch, ex_branch_dly1;
    logic [31:0] fu_vj; // Value for VJ
    logic [31:0] fu_vk; // Value for VK
    logic [2:0] fu_rs_tag;
    logic [31:0] store_data, store_data_dly1; // Data for store operation

    //ALU
    logic [31:0] alu_data_o; // ALU output data
    logic neg_o;
    logic zero_o;

    //ALU reg
    logic [31:0] alu_reg_in;
    logic [31:0] alu_reg_data;
    logic alu_valid; // ALU valid signal for CDB
    logic alu_valid_o; // ALU valid output signal for CDB
    logic alu_ready; // ALU ready signal

    // Data Memory
    logic [31:0] dm_addr_i; // Data memory address input
    logic [31:0] dm_data_o; // Data memory output data
    logic dm_valid; // Data memory valid signal
    logic dm_wr_en;
    logic datamem_fifo_empty;
    logic [31:0] dm_data_i;

    // Branch
    logic branch_taken,branch_taken_dly1; // Branch taken signal

    // Multiply

    logic muldiv_reset;
    logic [63:0] mul_o; // Multiply output data
    logic [31:0] mul_final_o;
    logic mul_ready; // Multiply valid input signal
    logic mul_valid_o; // Multiply valid output signal
    logic mul_valid; // Multiply valid input signal

    // Divider
    logic div_valid_o; // Divide ready signal
    logic div_valid; // Divide valid input signal
    logic div_ready; // Divide ready signal
    logic [31:0] div_o, rem_o;
    logic [31:0]div_final_o; // Final divide output signal
    
    // CDB ctrl
    logic [3:0] cdb_yumi; // CDB yumi signal
    cdb_packed_s packed_cdb_packet; // Packed CDB packet

    logic [3:0] cdb_rob_tag;
    logic cdb_store;

    /* ------------------------------ WR ------------------------------ */

    // Table
    logic [2:0] fu_rs_map [3:0];
    logic [7:0] rs_clear; // Reservation station clear signal

    /* ------------------------------ CM ------------------------------ */

    /*
        Instruction Fetch Stage
        Contains program counter, gshare unit, and instruction memory.
    */

    bp_se bp_se_inst (
        .instr(instr), 
        .pc(pc_reg), 
        .is_branch(is_branch), 
        .branch_target(branch_target)
    );
    gshare_unit gshare_unit_inst (
        .clk(clk_i), 
        .rst(reset_i), 
        .pc(pc), 
        .branch_valid(ex_branch), // This will be connected to the commit stage
        .branch_taken(branch_taken),  // This will be connected to the commit stage
        .branch_predict_taken(branch_predict_taken)    // For external usage if needed
    );
    program_counter program_counter_inst (
        .clk(clk_i), 
        .rst(reset_i), 
        .pc_write_en(pc_write_en), 
        .pc_in(pc), 
        .pc_out(pc_reg)
    );

    assign pc = recover_en ? pc_recover : 
                ctrl_jal ? jump_target : 
                (is_branch && branch_predict_taken) ? branch_target : pc_reg + 4; 

    assign pc_write_en = recover_en ? 1 : 
                        (rob_full||rs_full) ? 0 : 1;
    
    instructmem instructmem_inst (
        .address(pc_reg), 
        .instruction(instr), 
        .clk(clk_i)
    );
    
    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i || recover_en) begin
            ifis_pc <= 32'b0;
            ifis_instr <= 32'b0;
            ifis_branch_predict_taken <= 1'b0;
            ifis_branch_target <= 32'b0;
        end else if (rob_full||rs_full) begin
            ifis_pc <= ifis_pc;
            ifis_instr <= ifis_instr;
            ifis_branch_predict_taken <= ifis_branch_predict_taken;
            ifis_branch_target <= ifis_branch_target;
        end else if (ctrl_jal) begin
            ifis_pc <= 32'b0;
            ifis_instr <= 32'b0;
            ifis_branch_predict_taken <= 1'b0;
            ifis_branch_target <= 32'b0;
        end
        else begin
            ifis_pc <= pc_reg;
            ifis_instr <= instr;
            ifis_branch_predict_taken <= branch_predict_taken;
            ifis_branch_target <= branch_target;
        end
    end

    /*
        Instruction Issue Stage
        Contains instruction decoder, register file, regstat registers, reservation station 
        scheduler, reservation stations.
    */

    instruction_decoder instruction_decoder_inst (
        .instr(ifis_instr), 
        .rs1(rs1), 
        .rs2(rs2), 
        .rd(rd), 
        .opcode(opcode), 
        .func3(func3), 
        .func7(func7)
    );

    assign wr_en_i = (rob_head.branch || rob_head.store)? 0 : rob_commit_valid; // Write enable for register file
    assign wr_addr_i = rob_commit_dst[4:0]; // Write address for register file
    assign wr_data_i = rob_commit_data; // Write data for register file


    regfile regfile_inst (
        .clk_i(clk_i), 
        .wr_en_i(wr_en_i),
        .rd_addr1_i(rs1), 
        .rd_addr2_i(rs2), 
        .wr_addr_i(wr_addr_i), 
        .wr_data_i(wr_data_i),  
        .rd_data1_o(rs1_data), 
        .rd_data2_o(rs2_data)
    );

    sign_extender sign_extender_inst (
        .instr(ifis_instr), 
        .imm_out(imm_out)
    );

    control control_inst (
        .opcode(opcode), 
        .branch(ctrl_branch),  
        .jal(ctrl_jal), 
        .alu_src1(ctrl_alu_src1), 
        .alu_src2(ctrl_alu_src2),
        .alu_op(ctrl_alu_op),  
        .rs1_used(ctrl_rs1_used), 
        .rs2_used(ctrl_rs2_used), 
        .load(ctrl_load), 
        .store(ctrl_store)
    );

    alu_control alu_control_inst (
        .alu_op(ctrl_alu_op), 
        .funct3(func3), 
        .funct7(func7), 
        .alu_ctrl(is_alu_ctrl), 
        .fu_type(is_fu_type),
        .branch_type(is_branch_type)
    );

    assign jump_target = ctrl_jal ? ifis_pc + imm_out : 0;

    register_status register_status_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .recover_en(recover_en),
        .issue_valid(rss_issue_valid), 
        .commit_valid(rob_commit_valid),
        .cdb_valid(packed_cdb_packet.cdb_valid),
        .rs1(rs1), 
        .rs2(rs2), 
        .issue_dst(rd), 
        .commit_dst(rob_commit_dst[4:0]),
        .cdb_dest(cdb_dest[4:0]),
        .cdb_store(cdb_store),
        .issue_rob_tag(issue_rob_tag), 
        .commit_rob_tag(commit_rob_tag),
        .commit_store(commit_store),
        .cdb_rob_tag(packed_cdb_packet.cdb_rob_tag),
        .packed_rs1(packed_rs1), 
        .packed_rs2(packed_rs2)
    );

    assign rss_data1 = ctrl_alu_src1 ? ifis_pc : rs1_data;
    assign rss_data2 = ctrl_jal ? 'd4 : 
                    ctrl_alu_src2 ? imm_out : rs2_data;

    rs_scheduler rs_scheduler_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .packed_rs1(packed_rs1), 
        .packed_rs2(packed_rs2), 
        .issue_rob_tag(issue_rob_tag),
        .data1(rss_data1), 
        .data2(rss_data2), 
        .store_imm(imm_out),
        .rob_full(rob_full), 
        .alu_ctrl(is_alu_ctrl), 
        .fu_type(is_fu_type),
        .branch_type(is_branch_type),
        .ctrl_branch(ctrl_branch),  
        .ctrl_rs1_used(ctrl_rs1_used), 
        .ctrl_rs2_used(ctrl_rs2_used), 
        .ctrl_load(ctrl_load), 
        .ctrl_store(ctrl_store),
        .rs_full(rs_full),
        .packed_rs1_value(packed_rs1_value),
        .packed_rs2_value(packed_rs2_value),
        .rss_issue_valid(rss_issue_valid), 
        .packed_rs_entry(packed_rs_entry)
    );

    reservation_station reservation_station_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .recover_en(recover_en),
        .rss2rs_valid(rss_issue_valid),
        .packed_rs_entry(packed_rs_entry), 
        .fu_ready(fu_ready),
        .rs_clear(rs_clear),
        .cdb_packed(packed_cdb_packet), // CDB packed
        .rs_full(rs_full), 
        .rs2fu_valid(rs2fu_valid),
        .rs2fu_entry(rs2fu_entry), 
        .rs_fu_type(rs_fu_type),
        .rob_tag(rs_rob_tag),
        .rs_tag(rs_tag),
        .rs_alu_ctrl(rs_alu_ctrl),
        .cdb2rs_rs_tag(cdb2rs_rs_tag),
        .ex_load(ex_load),
        .load_addr(rs_load_addr),
        .load_rs_tag(fu_rs_tag),
        .load_req_valid(load_req_valid),
        .load_req_rob_addr(load_req_rob_addr),
        .load_req_addr(load_req_addr),
        .clear_load(clear_load)
    );

    reorder_buffer reorder_buffer_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .ifis_pc(ifis_pc), 
        .ifis_b_pred_taken(ifis_branch_predict_taken),
        .ifis_b_pred_target(ifis_branch_target),
        .issue_dst(rd),
        .issue_valid(rss_issue_valid), 
        .branch(ctrl_branch), 
        .store(ctrl_store),
        .store_data(rs2_data), 
        .issue_rob_tag(issue_rob_tag),
        .cdb_dest(cdb_dest),
        .cdb_store(cdb_store),
        .cdb_packed(packed_cdb_packet),
        .commit_valid(rob_commit_valid), 
        .commit_rob_tag(commit_rob_tag),
        .commit_value(rob_commit_data), 
        .commit_dst(rob_commit_dst),
        .commit_store(commit_store),
        .rob_full(rob_full), 
        .recover_en(recover_en),
        .recover_pc(pc_recover),
        .rob_head(rob_head),
        .packed_rs1_rob_tag(packed_rs1.rob_tag),
        .packed_rs2_rob_tag(packed_rs2.rob_tag),
        .packed_rs1_value(packed_rs1_value),
        .packed_rs2_value(packed_rs2_value)
    );

    assign datamem_fifo_dequeue = rob_head.ready & (rob_head.rob_addr == datamem_fifo_data_lo) & ~datamem_fifo_empty;
    assign datamem_fifo_enqueue = rss_issue_valid & ctrl_store & ~datamem_fifo_full;

    // fifo stores rob_addr corresponding to stores
    // enqueued from issue stage.
    fifo #(
        .data_width_p(4)
        ,.els_p(16)
    ) datamem_fifo (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .wr_i(datamem_fifo_enqueue),
        .wr_data_i(issue_rob_tag),
        .full_o(datamem_fifo_full),
        .rd_i(datamem_fifo_dequeue),
        .rd_data_o(datamem_fifo_data_lo),
        .empty_o(datamem_fifo_empty)
    );

    always_comb begin
        load_req_head_dist = load_req_rob_addr - rob_head.rob_addr; // mod 16, since 4 bits
        store_req_head_dist = datamem_fifo_data_lo - rob_head.rob_addr;
        load_before_store = load_req_head_dist < store_req_head_dist; // unsigned comparator

        // store: 0 - 13 = -13 % 16 = 3
        // load: 15 - 13 = 2 % 16 = 2
        // load req yumi is sent to relevant reservation station
        load_req_yumi = ( load_req_valid && (datamem_fifo_empty || load_before_store) ) ? 1 : 0;
    end

    /*
        Execute Stage
        Contains functional unit scheduler, adder/subtractor, multiplier, divider, data memory.
    */

    assign dm_addr_i = load_req_yumi? load_req_addr: rob_commit_dst;
    assign dm_wr_en = rob_head.ready & rob_head.store & rob_commit_valid; // to implement


    assign dm_data_i = rob_commit_data; // Data to write to data memory

    datamem datamem_inst (
        .clk_i(clk_i),
        .wr_en_i(dm_wr_en),
	    .addr_i(dm_addr_i),
	    .data_i(dm_data_i), // only store from front of ROB
	    .data_o(dm_data_o)     // synchronous reads
    );

    //always_ff(posedge clk_i or posedge reset_i) begin
    //    if (reset_i) begin
    //        dm_valid <= 1'b0;
    //    end else begin
    //        dm_valid <= load_req_yumi; // Reset data memory valid signal
    //    end
    //end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            dm_valid <= 1'b0;
        end else if (load_req_yumi) begin
            dm_valid <= 1'b1; // Data memory valid signal is set when load request is ready
        end else begin
            dm_valid <= 1'b0; 
        end
    end
    
    fu_ctrl fu_ctrl_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .recover_en(recover_en),
        .rs2fu_valid(rs2fu_valid),
        .packed_rsfu_entry(rs2fu_entry), 
        .rs_fu_type(rs_fu_type),
        .alu_ready(alu_ready), 
        .mul_ready(mul_ready), 
        .div_ready(div_ready),
        .mul_valid_o(mul_valid_o),
        .div_valid_o(div_valid_o),
        .fu_ready(fu_ready), 
        .alu_ctrl   (ex_alu_ctrl), 
        .fu_type    (ex_fu_type), 
        .branch_type(ex_branch_type),
        .alu_valid(alu_valid), 
        .mul_valid(mul_valid), 
        .div_valid(div_valid),
        .is_store   (ex_store), 
        .is_load    (ex_load), 
        .is_branch  (ex_branch),
        .store_data(store_data), // Store data for functional unit
        .fu_vj(fu_vj), 
        .fu_vk(fu_vk),
        .fu_rs_tag(fu_rs_tag)
    );

    alu alu_inst (
        .a_i(fu_vj), 
        .b_i(fu_vk), 
        .cntrl_i(ex_alu_ctrl), 
        .data_o(alu_data_o), 
        .neg_o(neg_o), 
        .zero_o(zero_o)
    );

    //assign alu_reg_in = ex_load ? 'd0 : alu_data_o; // ALU input selection
    assign load_addr_valid = (ex_load && alu_valid) ? 'd1 : 'd0;
    assign rs_load_addr = ex_load ? alu_data_o : 'd0; // Load address selection


    alu_passthrough alu_passthru_inst (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .alu_valid(alu_valid),
        .alu_ready(alu_ready),
        .alu_reg_in(alu_data_o),
        .alu_valid_o(alu_valid_o),
        .yumi_i(cdb_yumi[3]),
        .alu_reg_out(alu_reg_data)
    );
    

    always_comb begin
        if(ex_branch) begin
            case (ex_branch_type) // Branch type (0: None, 1: BEQ, 2: BNE, 3: BLT)
                2'd1: branch_taken = zero_o;
                2'd2: branch_taken = !zero_o;
                2'd3: branch_taken = neg_o;
                default: branch_taken = 0;
            endcase
        end else begin
            branch_taken = 0;
        end
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            ex_branch_dly1 <= 1'b0;
            branch_taken_dly1 <= 1'b0;
            ex_load_dly1 <= 1'd0;
        end else begin
            ex_branch_dly1 <= ex_branch; // Delay branch signal by one cycle
            branch_taken_dly1 <= branch_taken; // Delay branch taken signal by one cycle
            ex_load_dly1 <= ex_load;
        end
    end

    assign muldiv_reset = reset_i || recover_en;

    booth_mult #(.data_width_p(32)) booth_inst (
      .clk_i(clk_i),
      .reset_i(muldiv_reset),
      .v_i(mul_valid),
      .yumi_i(cdb_yumi[1]),
      .a_i(fu_vj),
      .b_i(fu_vk),
      .ready_o(mul_ready),
      .v_o(mul_valid_o),
      .data_o(mul_o)
    );

    assign mul_final_o = rs_alu_ctrl ? mul_o[63:32] : mul_o[31:0];  // 0:mul,1:mulh

    nrd_div #(.data_width_p(32)) div_inst (
      .clk_i(clk_i),
      .reset_i(muldiv_reset),
      .signed_i(1'b1),
      .v_i(div_valid),
      .yumi_i(cdb_yumi[0]),
      .a_i(fu_vj),
      .b_i(fu_vk),
      .ready_o(div_ready),
      .v_o(div_valid_o),
      .div_o(div_o),
      .rem_o(rem_o)
    );

    assign div_final_o = rs_alu_ctrl ? rem_o : div_o;  // 0:div,1:rem

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            store_data_dly1 <= 32'b0; // Reset store data delay register
        end else begin
            store_data_dly1 <= store_data; // Update store data delay register
        end
    end

    assign cdb_rob_tag = dm_valid ? load_req_rob_addr : rs_rob_tag;

    // CDB Control
    cdb_ctrl cdb_ctrl_inst (
        .clk_i(clk_i), 
        .reset_i(reset_i), 
        .cdb_rob_tag(cdb_rob_tag), // Reorder buffer tag of the instruction writing to it
        .dm_data(dm_data_o), 
        .alu_reg_data(alu_reg_data), 
        .mul_final_o(mul_final_o), 
        .div_final_o(div_final_o),
        .datamem_valid(dm_valid),
        .ex_load(ex_load_dly1),
        .ex_branch(ex_branch_dly1),
        .branch_taken(branch_taken_dly1),
        .store_data(store_data_dly1),
        .alu_valid(alu_valid_o), 
        .mul_valid(mul_valid_o), 
        .div_valid(div_valid_o),
        .packed_cdb_packet(packed_cdb_packet),
        .cdb_yumi(cdb_yumi)
    );

    /*
        Write Stage
        Contains common data bus controller, common data bus.
    */

    always_comb begin
        if(packed_cdb_packet.cdb_valid) begin
            case(cdb_yumi)
                4'b0001: cdb2rs_rs_tag = fu_rs_map[3]; // divider
                4'b0010: cdb2rs_rs_tag = fu_rs_map[2]; // multiplier
                //4'b0100: cdb2rs_rs_tag = load_req_rob_addr; // datamem
                4'b1000: cdb2rs_rs_tag = fu_rs_map[1]; // alu
                default: cdb2rs_rs_tag = 3'b000; // No valid operation
            endcase
        end else begin
            cdb2rs_rs_tag = 3'b000; // Reset RS tag if no valid CDB packet
        end
    end

    logic [2:0] rs_tag_dly1;

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            rs_tag_dly1 <= 3'b000; // Reset RS tag delay register
        end else begin
            rs_tag_dly1 <= rs_tag; // Update RS tag delay register
        end
    end

    always_ff @(posedge clk_i or posedge reset_i) begin
        if (reset_i) begin
            fu_rs_map[0] <= 0; // Data Memory
            fu_rs_map[1] <= 0; // ALU
            fu_rs_map[2] <= 0; // Multiply
            fu_rs_map[3] <= 0; // Divide
        end else begin
            if(alu_valid || mul_valid || div_valid || load_req_valid)begin
                case(ex_fu_type)
                    2'b00: fu_rs_map[0] <= rs_tag_dly1;  // Data Memory
                    2'b01: fu_rs_map[1] <= rs_tag_dly1;  // ALU
                    2'b10: fu_rs_map[2] <= rs_tag_dly1;  // Multiply
                    2'b11: fu_rs_map[3] <= rs_tag_dly1;  // Divide
                endcase
            end
        end
    end

   //Table for mapping rob tag to CDB
    always_comb begin
        rs_clear = 8'b0;
        case(cdb_yumi)
            4'b0001: rs_clear = 8'b1 << fu_rs_map[3]; // divider
            4'b0010: rs_clear = 8'b1 << fu_rs_map[2]; // multiplier
            4'b0100: rs_clear = 8'b1 << fu_rs_map[0]; // datamem
            4'b1000: rs_clear = 8'b1 << fu_rs_map[1]; // alu
            default: rs_clear = 0; // No valid operation
        endcase
    end

    assign clear_load = (cdb_yumi==4'b0100) ? 'd1 : 'd0;

    /*
        Commit Stage
        Contains reorder buffer.
    */


endmodule
