/*
*   core_probe.sv probes the register and memory values for use in monitor testing
*/

`include "../../../../RTL/memory/macros.vh"

interface core_probe();
    logic [31:0] registers [0:31];
    logic [31:0] memory [0:`MEM_DEPTH-1];
    logic core_halt;
endinterface