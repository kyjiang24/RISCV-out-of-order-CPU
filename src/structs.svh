`ifndef STRUCTS_SVH  // header guard to prevent multiple include error
`define STRUCTS_SVH

// need to know: if register is busy and if so which instruction is writing to it. 
typedef struct packed {
    // TODO: fill in fields
    logic busy;                // Is the register busy?
    logic re_busy;
    logic [3:0] rob_tag;       // Reorder buffer tag of the instruction writing to it
} register_status_s;  // RegStat entry

// need to know: if busy, instruction result, what to do with result, where to put
// it, and additional information for branches.
typedef struct packed {
    // TODO: fill in fields
    logic        busy;
    logic [31:0]  dest_reg;
    logic [31:0] value;
    logic        ready;
    logic        branch;
    logic       branch_predict_taken;
    logic [31:0] branch_target; // Target address for branch instruction
    logic        store;
    logic [31:0] store_data;
    logic [31:0] pc;
} rob_s;  // ROB entry

typedef struct packed {
    // TODO: fill in fields
    logic        ready;
    logic [31:0] value;
    logic [31:0]      addr;
    logic [3:0]      rob_addr;  // Address value 0-15 of head entry (implemented with circular FIFO)
    logic        store; // Is the head entry a store instruction?
    logic [31:0] store_data;
    logic       branch; // Is the head entry a branch instruction?
    logic   branch_taken; // Is the branch taken?
    logic     branch_predict_taken; // Is the branch prediction taken?
    logic [31:0] branch_target; // Target address for branch instruction
} rob_head_s;  // ROB head

typedef struct packed {
    // TODO: fill in fields
    logic [31:0] vj;
    logic [31:0] vk;    
    logic [31:0] qj;       
    logic [31:0] qk;   
    logic [31:0] store_imm; // Immediate value for store instruction
    logic [3:0]  rob_tag;       // Reorder buffer tag
    logic [2:0]  alu_ctrl;       // ALU control signal
    logic [1:0]  fu_type;        // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    logic        branch;        // Is it a branch instruction?
    logic        load;         // Is it a load instruction?
    logic        store;        // Is it a store instruction?
    logic [1:0]  branch_type;
    logic [2:0]  rs_tag;
    logic [31:0]  load_addr;  
    logic        load_addr_valid; // Load request valid signal

} reservation_station_s;  // RS entry

typedef struct packed {
    // TODO: fill in fields
    logic [31:0] vj;
    logic [31:0] vk;       
    logic [3:0]  rob_tag;       // Reorder buffer tag
    logic [2:0]  alu_ctrl;       // ALU control signal
    logic [1:0]  fu_type;        // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    logic        branch;        // Is it a branch instruction?
    logic        load;         // Is it a load instruction?
    logic        store;        // Is it a store instruction?
    logic [31:0] store_data;
    logic [1:0]  branch_type;
    logic [2:0]  rs_tag;
    
} rs2fu_s;  // RS entry


typedef struct packed {
    // TODO: fill in fields
    logic cdb_valid;       // Is the CDB packet valid?
    logic [3:0] cdb_rob_tag;  // Reorder buffer tag of the instruction writing to it
    logic [31:0] cdb_data;     // Data to be written to the register file
    logic [31:0] cdb_store_data; // Data for store instruction
} cdb_packed_s;  // CDB packet

typedef struct packed {
    // TODO: fill in fields
    logic [31:0] vj;
    logic [31:0] vk;
    logic [31:0] qj;       
    logic [31:0] qk;
    logic [31:0] store_imm;     
    logic [3:0]  rob_tag;       // Reorder buffer tag
    logic [2:0]  alu_ctrl;       // ALU control signal
    logic [1:0]  fu_type;        // Function unit type (0: Load/Store, 1: ALU, 2: Multiply, 3: Divide)
    logic [1:0]  branch_type;
    logic        branch;        // Is it a branch instruction?
    logic        load;         // Is it a load instruction?
    logic        store;        // Is it a store instruction?
} rs_scheduler_s;  // RS scheduler

`endif  // STRUCTS_SVH
