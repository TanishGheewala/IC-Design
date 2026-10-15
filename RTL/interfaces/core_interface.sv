/*
* Interface for the RISC-V core
*/

interface core_interface #(
    parameter int ROM_ADDR_WIDTH    = 13,
    parameter int MEMORY_ADDR_WIDTH = 13
)();

    logic clk;
    logic rst_n;

    logic        core_halt;
    logic [7:0]  debug_controller_instruction;
    logic [31:0] debug_address;
    logic [31:0] debug_data_return;

    // Data-memory interface
    logic                         memory_write_en;
    logic [3:0]                   memory_write_mask;
    logic [MEMORY_ADDR_WIDTH-1:0] memory_address;
    logic [31:0]                  memory_read;
    logic [31:0]                  memory_write;

    // Instruction-memory interface
    logic [ROM_ADDR_WIDTH-1:0] rom_address;
    logic [31:0]               rom_read;

    modport dut
    (
        input  clk,
        input  rst_n,
        input  core_halt,
        input  debug_controller_instruction,
        input  debug_address,
        input  memory_read,
        input  rom_read,

        output debug_data_return,
        output memory_write_en,
        output memory_write_mask,
        output memory_address,
        output memory_write,
        output rom_address
    );

endinterface
