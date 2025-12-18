`include "macros.svh"
module regfile (
    input  logic         clk_i,
    input  logic         wr_en_i,
    input  logic [4:0]   rd_addr1_i, //rs1
    input  logic [4:0]   rd_addr2_i, //rs2
    input  logic [4:0]   wr_addr_i,
    input  logic [31:0]  wr_data_i,
    output logic [31:0]  rd_data1_o, //rs1_data
    output logic [31:0]  rd_data2_o //rs2_data
);

    logic [31:0] registers [31:0];

    always_ff @(posedge clk_i) begin
        if (wr_en_i && wr_addr_i != 5'd0)
            registers[wr_addr_i] <= wr_data_i;
        registers[0] <= 32'd0;
    end

    /*assign rd_data1_o = (rd_addr1_i == 5'd0) ? 32'd0 : registers[rd_addr1_i];
    assign rd_data2_o = (rd_addr2_i == 5'd0) ? 32'd0 : registers[rd_addr2_i];*/

    assign rd_data1_o = (rd_addr1_i == 5'd0) ? 32'd0 :
                    ((rd_addr1_i == wr_addr_i) && wr_en_i) ? wr_data_i :
                    registers[rd_addr1_i];

    assign rd_data2_o = (rd_addr2_i == 5'd0) ? 32'd0 :
                    ((rd_addr2_i == wr_addr_i) && wr_en_i) ? wr_data_i :
                    registers[rd_addr2_i];


	`ifdef TESTING_NON_SYNTH  // Simulation-only code
        // Expected memory contents from file
        logic [31:0] expected_regs [32:0];

        // Counter to track clock cycles
        int cycle_count = 0;
        
        // Read expected results from a macro-defined file  
        initial begin
            $readmemh({"../tests/benchmarks/results/", `BENCHMARK, "_results.txt"}, expected_regs);
        end

        always_ff @(posedge clk_i) begin
            cycle_count <= cycle_count + 1;
        end
    
        // Assertion to check memory contents after `SIM_CYCLES cycles
        always_ff @(posedge clk_i) begin
            if (cycle_count == `SIM_CYCLES && expected_regs[0] == 32'hffff_ffff) begin
                $display("Beginning testing after %0d cycles", `SIM_CYCLES);
                for (int i = 0; i < 32; i++) begin
                    if (expected_regs[i+1] !== 32'hXXXX_XXXX)
                        assert (expected_regs[i+1] == registers[i]) else
                            $error("Incorrect register contents at address %0d\nExpected: %0d. Found: %0d",
                            i, expected_regs[i+1], registers[i]);
                end
                //for (int i = 0; i < 32; i++) begin
                //    $display("Register %0d: Expected %0d, Found %0d", i, expected_regs[i+1], registers[i]);
                //end
            end
        end
    `endif // TESTING_NON_SYNTH 

endmodule