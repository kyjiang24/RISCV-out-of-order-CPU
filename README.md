# RISCV-out-of-order-CPU
Out-of-order RISC-V core implementing a 4-stage pipeline (fetch, issue, execute, commit) with speculative execution. Uses Tomasulo’s algorithm with ROB-based register renaming, reservation stations, gshare branch prediction, long-latency mul/div units, and a store buffer enforcing conservative memory ordering.
