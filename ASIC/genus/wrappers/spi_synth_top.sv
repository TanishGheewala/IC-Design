// SPI Bootloader Wrapper for Synthesis

`default_nettype none

module spi_synth_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 13,
    parameter IMAGE_SIZE = 6144,
    parameter POWERUP_CYCLES = 80000
)
(
    //SPI Interface
    input logic clk,
    input logic rst_n,
    input logic miso,
    output logic mosi,
    output logic sclk,
    output logic cs_n,
    // Bootloader Ports
    output logic mem_we,
    output logic [DATA_WIDTH-1:0] mem_wdata,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [3:0] mem_wmask,
    output logic boot_done,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic flash_write_en,
    input  logic [DATA_WIDTH-1:0] image_size,
    output logic flash_write_done
);

spi_interface spi_if();

assign spi_if.clk = clk;
assign spi_if.rst_n = rst_n;
assign spi_if.miso = miso;
assign mosi = spi_if.mosi;
assign sclk = spi_if.sclk;
assign cs_n = spi_if.cs_n;

bootloader #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .IMAGE_BYTES(IMAGE_SIZE),
    .POWERUP_CYCLES(POWERUP_CYCLES)
) u_spi_bootloader (
    .spi_if(spi_if),
    .mem_we(mem_we),
    .mem_wdata(mem_wdata),
    .mem_addr(mem_addr),
    .mem_wmask(mem_wmask),
    .boot_done(boot_done),
    .mem_rdata(mem_rdata),
    .flash_write_en(flash_write_en),
    .image_size(image_size),
    .flash_write_done(flash_write_done)
);

endmodule

`default_nettype wire
