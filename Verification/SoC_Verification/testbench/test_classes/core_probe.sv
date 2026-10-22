/*
*   core_probe.sv probes the register and memory values for use in monitor testing
*/

`include "../../../../RTL/memory/macros.vh"

interface core_probe();
    logic [31:0] registers [0:31];
    logic [31:0] memory [0:(1 << 9) - 1];
    logic [9:0] gpio_in;
    logic [9:0] gpio_dir;
    logic [9:0] gpio_out;
    logic core_halt;
endinterface