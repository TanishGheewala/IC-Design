/*
* soc.sv is the top-most module of the chip. It contains the modules
* that make up the ASIC.
*
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

    //commands user can input to microcontroller
    typedef enum logic [7:0] {
        NOP,
        CORE_HALT,
        RETURN_REG,
        RETURN_MEM,
        RETURN_PC,
        FLASH_WRITE,
        CORE_RESUME = 8'hff
    }debug_command_t;
    
    //rom wires
    logic rom_write_en;
    logic [`DATA_WIDTH-1:0] rom_write;
    logic [`DATA_WIDTH-1:0] rom_read;
    logic [MEMORY_ADDR_WIDTH-1:0] rom_address;
    logic [3:0] rom_write_mask;

    //boot wires
    logic boot_write_en;
    logic flash_write_en;
    logic flash_write_done;
    logic [`DATA_WIDTH-1:0] boot_image_size;
    logic [`DATA_WIDTH-1:0] boot_write;
    logic [`DATA_WIDTH-1:0] boot_read;
    logic [MEMORY_ADDR_WIDTH-1:0] boot_address;
    logic [3:0] boot_write_mask;
    logic boot_done;

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
    debug_interface_v2 debug_if();
    gpio_interface gpio_if();
    io_interface io_if();
    spi_interface spi_if();

    // Debug controller
    debug_controller_v2 debug_con (
        .debug_if(debug_if)
    );

    gpio gpio_block (
        .gpio_if(gpio_if),
        .bus(io_if)
    );

    bootloader bootl (
        .spi_if(spi_if.spi_dut),
        .mem_we(boot_write_en),
        .mem_wdata(boot_write),
        .mem_addr(boot_address),
        .mem_wmask(boot_write_mask),
        .boot_done(boot_done),
        .image_size(boot_image_size),
        .flash_write_en(flash_write_en),
        .flash_write_done(flash_write_done),
        .mem_rdata(boot_read)
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
        .addr     (rom_address),
        .data_in  (rom_write),
        .data_out (rom_read)
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

    initial begin
        $monitor("boot_done: %0h", boot_done);
    end

    // Top-level and intermodule connections
    always_comb begin
        // Defaults to avoid latches
        rom_write_en = '0;
        rom_write = '0;
        rom_address = '0;
        rom_write_mask = '0;
        boot_read = '0;
        boot_image_size = debug_if.write_data;

        // Clock and temporary reset connection
        core0_if.clk = soc_if.clk;

        // UART debug connections
        debug_if.clk = soc_if.clk;
        debug_if.rx  = soc_if.rx;
        soc_if.tx    = debug_if.tx;

        // Debug-controller/core connections
        debug_if.core_data = core0_if.debug_data_return;
        core0_if.debug_address = debug_if.data_address;
        core0_if.debug_controller_instruction = debug_if.command;
        core0_if.core_halt = debug_if.core_halt;
        flash_write_en = debug_if.flash_write_en;
        debug_if.flash_write_done = flash_write_done;
        debug_if.rst_n = soc_if.rst_n;

        //in place of bootloader and gpio
        gpio_if.clk = soc_if.clk;
        soc_if.gpio_out = gpio_if.gpio_out;
        soc_if.gpio_oe  = gpio_if.gpio_oe;
        gpio_if.gpio_in = soc_if.gpio_in;

        //bootloader connections
        spi_if.clk = soc_if.clk;
        spi_if.rst_n = soc_if.rst_n;
        soc_if.sclk = spi_if.sclk;
        soc_if.mosi = spi_if.mosi;
        spi_if.miso = soc_if.miso;
        soc_if.cs_n = spi_if.cs_n;

        //bootloader start up sequence
        if(!boot_done) begin
            core0_if.rst_n = 1'b0;
            rom_write_en = boot_write_en;
            rom_write_mask = boot_write_mask;
            rom_address = boot_address;
            rom_write = boot_write;
            boot_read = rom_read;
            core0_if.rom_read = '0;
        end
        else if(debug_if.command == FLASH_WRITE) begin
            core0_if.rst_n = soc_if.rst_n;
            rom_write_en = debug_if.write_en;
            rom_write_mask = '1;
            boot_image_size = debug_if.write_data;
            if(debug_if.write_en) begin
                rom_address = debug_if.data_address;
                rom_write = debug_if.write_data;
            end
            else begin
                rom_address = boot_address;
                rom_write = '0;
            end
            boot_read = rom_read;
            core0_if.rom_read = '0;
        end
        else begin
            core0_if.rst_n = soc_if.rst_n;
            rom_write_en = 1'b0;
            rom_write_mask = '0;
            rom_address = core0_if.rom_address;
            rom_write = '0;
            core0_if.rom_read = rom_read;
            boot_read = '0;
        end

        //gpio and memory mux
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