/*
* soc.sv is the top-most module of the chip. It contains the modules
* that make up the ASIC.
*
* TODO: connect rst_n once the bootloader is created.
* TODO: adjust memory to split 8 KB between instruction memory,
*       data memory, and GPIO.
*/

`timescale 1ns/1ps
`include "../memory/macros.vh"

module soc #(
    parameter ROM_INITIAL_FILE = "test_program.hex"
)
(
    soc_interface soc_if
);

    // Interfaces
    core_interface  core0_if();
    debug_interface debug_if();

    // Debug controller
    debug_controller debug_con (
        .debug_if(debug_if)
    );

    // Data memory
    data_memory_sram8k data_memory (
        .clk      (soc_if.clk),
        .we       (core0_if.memory_write_en),
        .wmask    (core0_if.memory_write_mask),
        .addr     (core0_if.memory_address),
        .data_in  (core0_if.memory_write),
        .data_out (core0_if.memory_read)
    );

    // Temporary instruction memory for testing.
    // This will eventually be replaced with an SRAM block.
    instruction_memory #(
        .MEM_INITIAL_FILE(ROM_INITIAL_FILE)
    ) rom (
        .addr (core0_if.rom_address),
        .inst (core0_if.rom_read)
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
    always_comb
    begin
        // Clock and temporary reset connection
        core0_if.clk   = soc_if.clk;
        core0_if.rst_n = 1'b1;

        // UART debug connections
        debug_if.clk = soc_if.clk;
        debug_if.rx  = soc_if.rx;
        soc_if.tx    = debug_if.tx;

        // Debug-controller/core connections
        debug_if.data_return_in = core0_if.debug_data_return;

        core0_if.debug_address =
            debug_if.debug_address;

        core0_if.debug_controller_instruction =
            debug_if.core_signals;

        core0_if.core_halt =
            debug_if.core_halt;

        // GPIO is not connected yet.
        soc_if.gpio_out = '0;
        soc_if.gpio_oe  = '0;
    end

endmodule
