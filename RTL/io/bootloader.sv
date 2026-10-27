/*
FSM Hardware Implementation for Bootloader

Copies IMAGE_BYTES bytes from external SPI flash into the instruction SRAM
after reset, then raises boot_done. The core is held in reset until
boot_done = 1, so it starts executing from PC = 0 with the image in place.

Flash transaction (SPI mode 0, MSB first, standard 0x03 READ):
    cs_n low | 0x03 | A[23:16] | A[15:8] | A[7:0] | D0 | D1 | ... | Dn | cs_n high

Each data byte is written straight into SRAM through the byte mask:
    mem_addr  = byte_cntr, mem_wdata = {4{rx_byte}}, mem_wmask = 1 << byte_cntr[1:0]
so flash byte 0 lands in bits [7:0] of word 0 (little-endian).

spi_shift handshake: pulse start for one cycle, then wait for the done pulse.
rx_byte is valid on done and holds until the next transfer starts.
*/
`timescale 1ns / 1ps

module bootloader #(parameter int DATA_WIDTH = 32,
                    parameter int ADDR_WIDTH = 13,
                    parameter int FRAME_WIDTH = 8,
                    parameter int CLK_DIV = 4,
                    parameter int IMAGE_BYTES = 6144,
                    parameter logic [23:0] FLASH_BASE_ADDR = 24'h00_0000,
                    parameter int POWERUP_CYCLES = 2000 //change to 80000 for the clk from the FPGA board, 2000 for simulation
                )
                (
                    spi_interface.spi_dut spi_if, //clk,rst_n, sclk, mosi, miso, cs_n
                    output logic mem_we,
                    output logic [DATA_WIDTH-1:0] mem_wdata,
                    output logic [ADDR_WIDTH-1:0] mem_addr,
                    output logic [3:0] mem_wmask,
                    output logic boot_done
                );

localparam logic [7:0] READ_CMD = 8'h03;
localparam int WAIT_W = (POWERUP_CYCLES > 1) ? $clog2(POWERUP_CYCLES) : 1; //number of bits to count wait cycles
localparam int BYTE_W = (IMAGE_BYTES > 1) ? $clog2(IMAGE_BYTES) : 1; //number of bits to count bytes

//spi shift engine signals, SPI signlas are in spi_if
logic start;
logic [FRAME_WIDTH-1:0] tx_byte;
logic [FRAME_WIDTH-1:0] rx_byte;
logic busy, done;


logic [BYTE_W-1:0] byte_cntr; //counter for the number of bytes sent/received
logic [1:0] addr_idx;
logic [WAIT_W-1:0] wait_cntr;
logic xfer_pending; //a byte has been started and its done pulse hasn't arrived yet
logic cs_n_reg;

typedef enum logic [2:0] {
    POWER_ON,
    CS_LOW,
    SEND_CMD ,
    SEND_ADDR,
    READ_BYTE,
    WRITE_BYTE,
    CS_HIGH,
    DONE
}state_t;
state_t state, next_state;

//connect to spi_shift module, flash uses mode 0 (cpol = 0, cpha = 0), MSB first
spi_shift #(
    .FRAME_WIDTH(FRAME_WIDTH),
    .CLK_DIV(CLK_DIV)
) spi_shift_inst (
    .clk(spi_if.clk),
    .rst_n(spi_if.rst_n),
    .start(start),
    .tx_byte(tx_byte),
    .cpol(1'b0),
    .cpha(1'b0),
    .bit_order(1'b1),
    .rx_byte(rx_byte),
    .busy(busy),
    .done(done),
    .sclk(spi_if.sclk),
    .mosi(spi_if.mosi),
    .miso(spi_if.miso)
);

assign spi_if.cs_n = cs_n_reg;

//Byte transfer states: start one transfer per byte, then wait for done
logic xfer_state;
assign xfer_state = (state == SEND_CMD) || (state == SEND_ADDR) || (state == READ_BYTE);
assign start = xfer_state && !xfer_pending && !busy;

//Byte to shift out in each transfer state
always_comb begin
    case (state)
        SEND_CMD: tx_byte = READ_CMD;
        SEND_ADDR: begin
            case (addr_idx)
                2'd0: tx_byte = FLASH_BASE_ADDR[23:16];
                2'd1: tx_byte = FLASH_BASE_ADDR[15:8];
                default: tx_byte = FLASH_BASE_ADDR[7:0];
            endcase
        end
        default: tx_byte = '0; //dummy byte while reading data
    endcase
end

//Next state logic
always_comb begin
    next_state = state;
    case (state)
        POWER_ON: begin
            if (wait_cntr == WAIT_W'(POWERUP_CYCLES-1))
                next_state = CS_LOW;
        end
        CS_LOW: next_state = SEND_CMD;
        SEND_CMD: begin
            if (done)
                next_state = SEND_ADDR;
        end
        SEND_ADDR: begin
            if (done && addr_idx == 2'd2)
                next_state = READ_BYTE;
        end
        READ_BYTE: begin
            if (done)
                next_state = WRITE_BYTE;
        end
        WRITE_BYTE: begin
            if (byte_cntr == BYTE_W'(IMAGE_BYTES-1))
                next_state = CS_HIGH;
            else
                next_state = READ_BYTE;
        end
        CS_HIGH: next_state = DONE;
        DONE: next_state = DONE;
        default: next_state = POWER_ON;
    endcase
end

//State, counters, cs_n and boot_done registers
always_ff @(posedge spi_if.clk) begin
    if (!spi_if.rst_n) begin
        state <= POWER_ON;
        wait_cntr <= '0;
        addr_idx <= '0;
        byte_cntr <= '0;
        xfer_pending <= 1'b0;
        cs_n_reg <= 1'b1;
        boot_done <= 1'b0;
    end else begin
        state <= next_state;

        //transfer tracking: set on start, cleared on done
        if (start)
            xfer_pending <= 1'b1;
        else if (done)
            xfer_pending <= 1'b0;

        case (state)
            POWER_ON: wait_cntr <= wait_cntr + 1'b1;
            CS_LOW: cs_n_reg <= 1'b0;
            SEND_ADDR: begin
                if (done)
                    addr_idx <= addr_idx + 1'b1;
            end
            WRITE_BYTE: byte_cntr <= byte_cntr + 1'b1;
            CS_HIGH: begin
                cs_n_reg <= 1'b1;
                boot_done <= 1'b1;
            end
            default: ;
        endcase
    end
end

//SRAM write port: one byte lane per write
assign mem_we = (state == WRITE_BYTE);
assign mem_addr = ADDR_WIDTH'(byte_cntr);
assign mem_wdata = {(DATA_WIDTH/FRAME_WIDTH){rx_byte}};
assign mem_wmask = 4'b0001 << byte_cntr[1:0];

endmodule
