// Instruction Memory - Read-Only Memory (ROM)

`include "macros.vh"

module instruction_memory
(
    input clk;
    input we;
    input [`ADDR_WIDTH-1:0] addr,
    output [`DATA_WIDTH-1:0] inst
);

// ROM Array
reg [`DATA_WIDTH-1:0] rom [0:`MEM_DEPTH-1];

assign inst = rom[addr[`ADDR_WIDTH-1:2]];

endmodule