// NOT CREATED BY US.
// FROM: UC Santa Cruz VLSI Design and Automation design lab
// https://github.com/VLSIDA/sky130_sram_macros
// for testing purposes.

// OpenRAM SRAM model
// Words: 512
// Word size: 32
// Write size: 8

`timescale 1ns/1ps

module sky130_sram_2kbyte_1rw1r_32x512_8 (
    // Port 0: RW
    input  logic        clk0,
    input  logic        csb0,       // active low chip select
    input  logic        web0,       // active low write enable
    input  logic [3:0]  wmask0,     // write mask
    input  logic [8:0]  addr0,
    input  logic [31:0] din0,
    output logic [31:0] dout0,

    // Port 1: R
    input  logic        clk1,
    input  logic        csb1,       // active low chip select
    input  logic [8:0]  addr1,
    output logic [31:0] dout1
);

    (* ram_style = "block" *)
    logic [31:0] mem [0:511];

    // Port 0: Read / Write (Single rising clock edge)
    always_ff @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin
                if (wmask0[0]) mem[addr0][7:0]   <= din0[7:0];
                if (wmask0[1]) mem[addr0][15:8]  <= din0[15:8];
                if (wmask0[2]) mem[addr0][23:16] <= din0[23:16];
                if (wmask0[3]) mem[addr0][31:24] <= din0[31:24];
            end else begin
                dout0 <= mem[addr0];
            end
        end
    end

    // Port 1: Read-only (Single rising clock edge)
    always_ff @(posedge clk1) begin
        if (!csb1) begin
            dout1 <= mem[addr1];
        end
    end

endmodule