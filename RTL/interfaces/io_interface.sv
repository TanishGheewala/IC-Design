/*
* io_interface.sv - Shared memory-mapped peripheral bus.
*
* One instance connects the I/O sub-decoder (host side) to a single
* peripheral (device side). Every peripheral - UART, QSPI, and anything
* added later - connects through this same interface, so the decoder's
* select fan-out and read-data mux don't need per-device special casing.
*
* addr is the peripheral-local offset: the decoder strips the RAM/IO
* select bit (and any per-peripheral base) before driving this bus, so
* each peripheral only decodes its own register offsets, never the full
* address space.
*/
`timescale 1ns/1ps

interface io_interface #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)();

    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  we;
    logic                  sel;

    // Decoder/mux side: drives the transaction, reads back the peripheral's data.
    modport io_host
    (
        output addr,
        output wdata,
        output we,
        output sel,
        input  rdata
    );

    // Peripheral side: reacts to the transaction, drives its data back.
    modport io_dev
    (
        input  addr,
        input  wdata,
        input  we,
        input  sel,
        output rdata
    );

endinterface
