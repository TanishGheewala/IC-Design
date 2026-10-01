/*
* Interface for the data-address-space decoder. Splits the core's load/store
* address range between RAM and the memory-mapped I/O window, and gates each
* device's select/write-enable accordingly.
*/
`timescale 1ns/1ps
interface address_decoder_interface #(
    parameter int ADDR_WIDTH = 10
)();

    logic [ADDR_WIDTH-1:0] addr;
    logic                  mem_read;
    logic                  mem_write;

    logic ram_sel;
    logic ram_we;

    logic io_sel;
    logic io_we;
    logic [ADDR_WIDTH-1:0] io_addr; // addr with the I/O select bit stripped out

    modport ad_dut
    (
        input  addr,
        input  mem_read,
        input  mem_write,
        output ram_sel,
        output ram_we,
        output io_sel,
        output io_we,
        output io_addr
    );

endinterface
