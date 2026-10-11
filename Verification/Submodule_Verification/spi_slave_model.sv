/*
* frame() plays the slave's side of one FRAME_WIDTH-bit transfer following
* the SPI mode rules on its own, independent of the RTL. A master that
* samples or shifts on the wrong edge is caught here, where a mosi->miso
* loopback would still pass (the wrong edge is wrong the same way on both
* sides).
*
* Bytes are in wire order: bit [FRAME_WIDTH-1] is the first bit on the wire.
* Start frame() before the master's first sclk edge (fork it alongside the
* start of the transfer).
*/
`timescale 1ns/1ps

module spi_slave_model #(
    parameter int FRAME_WIDTH = 8
)(
    input  logic sclk,
    input  logic mosi,
    output logic miso
);

    initial miso = 1'b0;

    task automatic frame(input  bit                     cpol,
                         input  bit                     cpha,
                         input  logic [FRAME_WIDTH-1:0] miso_word,
                         output logic [FRAME_WIDTH-1:0] mosi_word);
        mosi_word = 'x;
        for (int i = FRAME_WIDTH-1; i >= 0; i--) begin
            //CPHA=0: bit must be valid before the leading edge
            if (!cpha) miso = miso_word[i];

            //leading edge
            if (cpol) @(negedge sclk); else @(posedge sclk);
            if (cpha) miso = miso_word[i];     //CPHA=1: change on leading
            else      mosi_word[i] = mosi;     //CPHA=0: sample on leading

            //trailing edge
            if (cpol) @(posedge sclk); else @(negedge sclk);
            if (cpha) mosi_word[i] = mosi;     //CPHA=1: sample on trailing
        end
    endtask

endmodule
