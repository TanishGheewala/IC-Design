// Instruction Memory - Read-Only Memory (ROM)

`include "macros.vh"

module instruction_memory 
#(
    MEM_INITIAL_FILE = "program.hex" // Path to .hex file for instantiating $readmemh
    // Note: In testbench, use #(.MEM_INITIAL_FILE("tests/program.hex")) or similar
) (
    //input clk,
    //input we,
    input [`ADDR_WIDTH-1:0] addr,
    output [`DATA_WIDTH-1:0] inst
);

// ROM Array
reg [`DATA_WIDTH-1:0] rom [0:`MEM_DEPTH-1];

// This initalizes the ROM with the program.hex file
initial begin
    if ((MEM_INITIAL_FILE) != "") begin 
        $readmemh(MEM_INITIAL_FILE, rom);
    end 
end

assign inst = rom[addr[`ADDR_WIDTH-1:2]];

endmodule
