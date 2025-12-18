// 1RW memory w/ synchronous reads

`include "macros.svh"
`define DATA_MEM_SIZE 256

module datamem (
    input logic clk_i, wr_en_i,
    input logic [31:0] addr_i, data_i,
    output logic [31:0] data_o
);
	// The data storage itself.
	logic [7:0] mem_r [`DATA_MEM_SIZE-1:0];
    logic [7:0] mem_n [`DATA_MEM_SIZE-1:0];

    always_ff @(posedge clk_i) begin
        mem_r <= mem_n;
    end

    always_comb begin
        mem_n = mem_r;
        if (wr_en_i)
            {mem_n[addr_i+3], mem_n[addr_i+2], mem_n[addr_i+1], mem_n[addr_i]} = data_i;
    end

    assign data_o = {mem_r[addr_i+3], mem_r[addr_i+2], mem_r[addr_i+1], mem_r[addr_i]};


    `ifdef TESTING_NON_SYNTH  // Only included if automated testing is enabled

        // Non-synth assertion, making sure given address is in bounds
        always_ff @(posedge clk_i) begin
            if (addr_i != 'x)
                assert(addr_i + 3 < `DATA_MEM_SIZE);
        end

        // Expected memory contents, loaded from file
        logic [7:0] expected_mem [`DATA_MEM_SIZE:0];

        // Counter to track clock cycles
        int cycle_count = 0;
        
        // Read expected results from a macro-defined file  
        initial begin
            $readmemh({"../tests/benchmarks/results/", `BENCHMARK, "_results.txt"}, expected_mem);
        end

        always_ff @(posedge clk_i) begin
            cycle_count <= cycle_count + 1;
        end
    
        // Assertion to check memory contents after `SIM_CYCLES cycles
        always_ff @(posedge clk_i) begin
            if (cycle_count == `SIM_CYCLES && {expected_mem[3], expected_mem[2], expected_mem[1],
                expected_mem[0]} == '0) begin

                $display("Beginning testing after %0d cycles", `SIM_CYCLES);
                for (int i = 0; i < `DATA_MEM_SIZE; i++) begin
                    if (expected_mem[i+4] !== 8'hXX) // xx corresponds to unused memory
                        assert (expected_mem[i+4] == mem_r[i]) else
                            $error("Incorrect memory contents at address %0d\n Expected: %0d. Found: %0d",
							i, expected_mem[i+4], mem_r[i]);
                end

            end // if
        end     // always_ff
    `endif      // TESTING_NON_SYNTH

endmodule
