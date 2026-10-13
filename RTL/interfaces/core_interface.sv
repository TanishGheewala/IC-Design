/*
* Interface for RISC V core
*/

interface core_interface();

    logic clk;
    logic rst_n;
    logic core_halt;
    logic [7:0] debug_controller_instruction;
    logic [31:0] debug_address;
    logic [31:0] debug_data_return;
    logic memory_write_en;
    logic [12:0] memory_address;

    //data word from memory
    logic [31:0] memory_read;
    logic [31:0] memory_write;
    logic [9:0] rom_address;
    
    //data word from rom instruction memory
    logic [31:0] rom_read;
    

    //dut setup
    modport dut
    (
        input clk,
        input rst_n,
        input core_halt,
        input debug_controller_instruction,
        input debug_address,
        input memory_read,
        input rom_address,
        output debug_data_return,
        output memory_write_en,
        output memory_address,
        output memory_write,
        output rom_read
    );

endinterface