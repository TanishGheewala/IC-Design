/*
SPI Master module

0x00  CTRL    RW  [0] cpol  [1] cpha  [2] bit_order (1 = MSB first)
                  [3] cs    (1 = drive cs_n low)
                  [15:8] reserved
0x04  STATUS  RO  [0] busy  [1] done (cleared by writing TXDATA)
0x08  TXDATA  WO  [7:0] byte to send; a write starts the transfer
0x0C  RXDATA  RO  [7:0] byte received in the last transfer

CTRL and TXDATA writes are ignored while busy. STATUS reads are valid at any time.
RXDATA is only valid once busy = 0: mid-frame it reads a partly shifted byte.
(Edit: RXDATA note added - the old line said RXDATA reads were valid at any time.)

Change cpol only while cs = 0 (write the mode with cs = 0 first, then set cs).
*/

`timescale 1ns/1ps

module spi_master #(
    parameter int FRAME_WIDTH = 8,
    parameter int DATA_WIDTH = 32, //bus width
    parameter int CLK_DIV = 4 //clk cycle per sclk half-period, >= 3 
                              
) (
    spi_interface.spi_dut spi_if,
    io_interface.io_dev  bus
);

// Register Addresses for the bus interface
localparam int REG_CTRL = 'h00;
localparam int REG_STATUS = 'h04;
localparam int REG_TXDATA = 'h08;
localparam int REG_RXDATA = 'h0C;

//Control Registers
logic cpol_reg;
logic cpha_reg;
logic bit_order_reg;

//outputs
logic cs_reg;
logic done_reg;

//Connections to spi_shift engine
logic start;
logic [FRAME_WIDTH-1:0] rx_byte;
logic busy, done;

assign start = bus.sel && bus.we && (bus.addr == REG_TXDATA) && !busy;

//connect to spi_shift module
spi_shift #(
    .FRAME_WIDTH(FRAME_WIDTH),
    .CLK_DIV(CLK_DIV)
) spi_shift_inst (
    .clk(spi_if.clk),
    .rst_n(spi_if.rst_n),
    .start(start),
    .tx_byte(bus.wdata[FRAME_WIDTH-1:0]),
    .cpol(cpol_reg),
    .cpha(cpha_reg),
    .bit_order(bit_order_reg),
    .rx_byte(rx_byte),
    .busy(busy),
    .done(done),
    .sclk(spi_if.sclk),
    .mosi(spi_if.mosi),
    .miso(spi_if.miso)
);

assign spi_if.cs_n = ~cs_reg; //active low

//Register Write Logic
always_ff @(posedge spi_if.clk) begin
    if (!spi_if.rst_n) begin
        done_reg <= 1'b0;
        cs_reg <= 1'b0;
        cpol_reg <= 1'b0;
        cpha_reg <= 1'b0;
        bit_order_reg <= 1'b0;
    end else begin
        if (bus.sel && bus.we && (bus.addr == REG_CTRL) && !busy) begin
            cpol_reg <= bus.wdata[0];
            cpha_reg <= bus.wdata[1];
            bit_order_reg <= bus.wdata[2];
            cs_reg <= bus.wdata[3];
        end
        if (start) begin
            done_reg <= 1'b0;
        end else if (done) begin
            done_reg <= 1'b1;
        end
    end
end

//Register Read Logic
always_comb begin
    bus.rdata = '0;
    case (bus.addr)
        REG_CTRL: bus.rdata[3:0] = {cs_reg, bit_order_reg, cpha_reg, cpol_reg};
        REG_STATUS: bus.rdata[1:0] = {done_reg | done, busy}; //OR in the live pulse makes done show in the same cycle busy clears.
        REG_RXDATA: bus.rdata[FRAME_WIDTH-1:0] = rx_byte;
        default: ;
    endcase
end

endmodule