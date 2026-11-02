// Core Wrapper

module core_synth_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        core_halt,
    input  logic [7:0]  debug_controller_instruction,
    input  logic [31:0] debug_address,
    input  logic [31:0] memory_read,
    input  logic [31:0] rom_read,

    output logic [31:0] debug_data_return,
    output logic        memory_write_en,
    output logic [3:0]  memory_write_mask,
    output logic [12:0] memory_address,
    output logic [31:0] memory_write,
    output logic [12:0] rom_address
);
    core_interface core_if();

    assign core_if.clk                          = clk;
    assign core_if.rst_n                        = rst_n;
    assign core_if.core_halt                    = core_halt;
    assign core_if.debug_controller_instruction = debug_controller_instruction;
    assign core_if.debug_address                = debug_address;
    assign core_if.memory_read                  = memory_read;
    assign core_if.rom_read                     = rom_read;

    assign debug_data_return = core_if.debug_data_return;
    assign memory_write_en   = core_if.memory_write_en;
    assign memory_write_mask = core_if.memory_write_mask;
    assign memory_address    = core_if.memory_address;
    assign memory_write      = core_if.memory_write;
    assign rom_address       = core_if.rom_address;

    core u_core (.core_if(core_if));
endmodule
