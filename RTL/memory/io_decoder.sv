// io_decoder.sv - Second-stage decoder for the memory-mapped I/O window
//
// address_decoder decides RAM vs. I/O. This module takes the I/O half of
// that decision (io_sel / io_we / io_addr) and splits it across
// NUM_PERIPHS peripherals, each connected through its own io_interface.
//
// Every peripheral owns an equal, power-of-two sized slot of the window,
// so decoding is just a bit-slice of io_addr:
//
//   io_addr = { 0 | slot index                   | local offset     }
//               ^   [IO_SEL_BIT-1 : SLOT_BITS]     [SLOT_BITS-1 : 0]
//               stripped by address_decoder
//
// Defaults (10-bit address, 64 B slots) give 8 slots of 16 word registers:
//   slot 0 : 0x200-0x23F    slot 4 : 0x300-0x33F
//   slot 1 : 0x240-0x27F    slot 5 : 0x340-0x37F
//   slot 2 : 0x280-0x2BF    slot 6 : 0x380-0x3BF
//   slot 3 : 0x2C0-0x2FF    slot 7 : 0x3C0-0x3FF
//
// Slots at or above NUM_PERIPHS are unmapped: writes are dropped and reads
// return 0.
//
// Each io_interface in periph_if must be instantiated with
// ADDR_WIDTH = SLOT_BITS, since peripherals only see their local offset.

`timescale 1ns/1ps

module io_decoder #(
    parameter int ADDR_WIDTH  = 10,
    parameter int DATA_WIDTH  = 32,
    parameter int SLOT_BITS   = 6,
    parameter int NUM_PERIPHS = 4
)(
    io_decoder_interface.iod_dut dec_if,
    io_interface.io_host         periph_if [NUM_PERIPHS]
);

    localparam int IO_SEL_BIT = ADDR_WIDTH - 1;
    localparam int IDX_BITS   = IO_SEL_BIT - SLOT_BITS;

    if (IDX_BITS < 1 || NUM_PERIPHS > (1 << IDX_BITS))
        $error("io_decoder: NUM_PERIPHS=%0d does not fit in the I/O window with SLOT_BITS=%0d",
               NUM_PERIPHS, SLOT_BITS);

    logic [IDX_BITS-1:0]   slot;
    logic [DATA_WIDTH-1:0] periph_rdata [NUM_PERIPHS];

    assign slot = dec_if.io_addr[IO_SEL_BIT-1:SLOT_BITS];

    // Interface arrays can only be indexed by constants, so fan-out and
    // rdata collection happen in a generate loop; the mux below then works
    // on a plain array.
    for (genvar i = 0; i < NUM_PERIPHS; i++) begin : g_periph
        always_comb begin
            periph_if[i].sel   = dec_if.io_sel & (slot == i);
            periph_if[i].we    = dec_if.io_we  & (slot == i);
            periph_if[i].addr  = dec_if.io_addr[SLOT_BITS-1:0];
            periph_if[i].wdata = dec_if.wdata;
        end

        assign periph_rdata[i] = periph_if[i].rdata;
    end

    // Gated by io_sel so rdata is a clean 0 on non-I/O cycles; the core-side
    // RAM/I/O load mux can then rely on it without extra qualification.
    always_comb begin
        dec_if.rdata = '0;
        if (dec_if.io_sel && slot < NUM_PERIPHS)
            dec_if.rdata = periph_rdata[slot];
    end

endmodule
