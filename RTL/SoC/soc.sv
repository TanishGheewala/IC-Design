/*
* soc.sv is the top-most module of the chip. It contains the modules
* that make up the ASIC.
*
* TODO: connect rst_n once the bootloader is created.
*/

`timescale 1ns/1ps
`include "../memory/macros.vh"

module soc #(
    parameter ROM_INITIAL_FILE = "test_program.hex",
    parameter MEMORY_ADDR_WIDTH = 13,
    parameter GPIO_WIDTH = 10
)
(
    soc_interface soc_if
);

    //temp wires in place of bootloader;
    logic rom_write_en;
    logic [`DATA_WIDTH-1:0] rom_write;
    logic [3:0] rom_write_mask;

    //gpio wires from mux
    logic [MEMORY_ADDR_WIDTH-1:0] gpio_address;
    logic gpio_write_en;
    logic [31:0] gpio_write;
    logic [31:0] gpio_read;

    //memory wires for mux
    logic [MEMORY_ADDR_WIDTH-1:0] memory_address;
    logic memory_write_en;
    logic [31:0] memory_write;
    logic [31:0] memory_read;

    // Interfaces
    core_interface  core0_if();
    debug_interface debug_if();
    gpio_interface gpio_if();
    io_interface io_if();




    // Debug controller
    debug_controller debug_con (
        .debug_if(debug_if)
    );
    
    gpio gpio_block (
        .gpio_if(gpio_if),
        .bus(io_if)
    );

    // Data memory
    data_memory_sram2k data_memory (
        .clk      (soc_if.clk),
        .we       (memory_write_en),
        .wmask    (core0_if.memory_write_mask),
        .addr     (memory_address),
        .data_in  (memory_write),
        .data_out (memory_read)
    );

    //instruction rom
    instruction_memory_sram6k instruction_rom (
        .clk      (soc_if.clk),
        .we       (rom_write_en),
        .wmask    (rom_write_mask),
        .addr     (core0_if.rom_address),
        .data_in  (rom_write),
        .data_out (core0_if.rom_read)
    );

    // Processor core
    core #(
        .ADDR_WIDTH       (`ADDR_WIDTH),
        .MEM_DEPTH        (`MEM_DEPTH),
        .ROM_INITIAL_FILE (ROM_INITIAL_FILE),
        .RAM_INITIAL_FILE (""),
        .DEBUG_PRINT      (1'b0)
    ) core0 (
        .core_if(core0_if)
    );

    // Top-level and intermodule connections
    always_comb begin
        // Clock and temporary reset connection
        core0_if.clk   = soc_if.clk;
        core0_if.rst_n = 1'b1;

        // UART debug connections
        debug_if.clk = soc_if.clk;
        debug_if.rx  = soc_if.rx;
        soc_if.tx    = debug_if.tx;

        // Debug-controller/core connections
        debug_if.data_return_in = core0_if.debug_data_return;
        core0_if.debug_address = debug_if.debug_address;
        core0_if.debug_controller_instruction = debug_if.core_signals;
        core0_if.core_halt = debug_if.core_halt;

        // in place of bootloader and gpio
        gpio_if.clk = soc_if.clk;
        soc_if.gpio_out = gpio_if.gpio_out;
        soc_if.gpio_oe  = gpio_if.gpio_oe;
        gpio_if.gpio_in = soc_if.gpio_in;
        rom_write = '0;
        rom_write_en = '0;
        rom_write_mask = '0;

        //mux for gpio
        if(core0_if.memory_address[MEMORY_ADDR_WIDTH-1]) begin
            io_if.addr = core0_if.memory_address[9:0];
            io_if.we = core0_if.memory_write_en;
            io_if.wdata = core0_if.memory_write;
            core0_if.memory_read = io_if.rdata;

            memory_address = '0;
            memory_write_en = '0;
            memory_write = '0;
        end
        else begin
            io_if.addr = '0;
            io_if.we = '0;
            io_if.wdata = '0;

            memory_address = core0_if.memory_address;
            memory_write_en = core0_if.memory_write_en;
            memory_write = core0_if.memory_write;
            core0_if.memory_read = memory_read;
        end
    end

endmodule
