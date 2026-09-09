// Instruction Memory - Read-Only Memory (ROM)

`include "macros.vh"

module instruction_memory
#(
    parameter ADDR_WIDTH = `ADDR_WIDTH,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter MEM_DEPTH = `MEM_DEPTH,
    parameter MEM_INITIAL_FILE = "program.hex"
) (
    input [ADDR_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] inst
);

// ROM Array
reg [DATA_WIDTH-1:0] rom [0:MEM_DEPTH-1];

// This initializes the ROM with the program.hex file
initial begin
    if (MEM_INITIAL_FILE != "") begin
        $readmemh(MEM_INITIAL_FILE, rom);
    end
end

assign inst = rom[addr[ADDR_WIDTH-1:2]];

endmodule