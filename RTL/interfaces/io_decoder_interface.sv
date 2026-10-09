/*
* Interface for the I/O window sub-decoder. Its inputs are the I/O-side
* outputs of address_decoder (io_sel / io_we / io_addr) plus the core's
* store data; its output is the read data of whichever peripheral is
* currently selected. The per-peripheral side of io_decoder is carried by
* an array of io_interface instances, not by this interface.
*/
`timescale 1ns/1ps
interface io_decoder_interface #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)();

    logic [ADDR_WIDTH-1:0] io_addr;  // from address_decoder, I/O select bit already stripped
    logic                  io_sel;
    logic                  io_we;
    logic [DATA_WIDTH-1:0] wdata;    // core store data

    logic [DATA_WIDTH-1:0] rdata;    // muxed peripheral read data, 0 when no I/O access

    modport iod_dut
    (
        input  io_addr,
        input  io_sel,
        input  io_we,
        input  wdata,
        output rdata
    );

endinterface
