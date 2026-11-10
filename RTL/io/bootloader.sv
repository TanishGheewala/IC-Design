/*
FSM Hardware Implementation for Bootloader

Copies IMAGE_BYTES bytes from external SPI flash into instruction SRAM after reset,
then raises boot_done.

When flash_write_en is asserted, reads image data from SRAM and writes it into
external SPI flash using 256-byte Page Programs (0x02) preceded by Write Enable (0x06)
and followed by Status Register WIP polling (0x05).
*/
`timescale 1ns / 1ps

module bootloader #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 13,
    parameter int FRAME_WIDTH = 8,
    parameter int CLK_DIV = 4,
    parameter int IMAGE_BYTES = 6144,
    parameter logic [23:0] FLASH_BASE_ADDR = 24'h00_0000,
    parameter int POWERUP_CYCLES = 2000 // 80000 for board clock, 2000 for simulation
) (
    spi_interface.spi_dut spi_if, // clk, rst_n, sclk, mosi, miso, cs_n
    output logic mem_we,
    output logic [DATA_WIDTH-1:0] mem_wdata,
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [3:0] mem_wmask,
    output logic boot_done,
    input  logic [DATA_WIDTH-1:0] mem_rdata,
    input  logic flash_write_en,
    input  logic [DATA_WIDTH-1:0] image_size = DATA_WIDTH'(IMAGE_BYTES),
    output logic flash_write_done
);

localparam logic [7:0] READ_CMD       = 8'h03;
localparam logic [7:0] WRITE_EN_CMD   = 8'h06;
localparam logic [7:0] PAGE_WRITE_CMD = 8'h02;
localparam logic [7:0] STATUS_CMD     = 8'h05;

localparam int WAIT_W = (POWERUP_CYCLES > 1) ? $clog2(POWERUP_CYCLES) : 1;
localparam int BYTE_W = (IMAGE_BYTES > 1) ? $clog2(IMAGE_BYTES) : 1;

// SPI shift engine signals
logic start;
logic [FRAME_WIDTH-1:0] tx_byte;
logic [FRAME_WIDTH-1:0] rx_byte;
logic busy, done;

// Top-level Bootloader States
typedef enum logic [1:0] {
    BOOT_READ,
    IDLE,
    FLASH_WRITE
} bootloader_state_t;
bootloader_state_t bootloader_state, bootloader_next_state;

// =========================================================================
// SPI Shift Module Instance
// =========================================================================
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

// =========================================================================
// BOOT_READ State Machine (Original, Preserved)
// =========================================================================
typedef enum logic [3:0] {
    POWER_ON,
    CS_LOW,
    SEND_CMD,
    SEND_ADDR,
    READ_BYTE,
    WRITE_BYTE,
    CS_HIGH,
    DONE
} state_t;
state_t state, next_state;

logic [BYTE_W-1:0] byte_cntr;
logic [1:0] addr_idx;
logic [WAIT_W-1:0] wait_cntr;
logic xfer_pending;
logic cs_n_boot;
logic start_boot;
logic [FRAME_WIDTH-1:0] tx_byte_boot;

logic xfer_state_boot;
assign xfer_state_boot = (state == SEND_CMD) || (state == SEND_ADDR) || (state == READ_BYTE);
assign start_boot = (bootloader_state == BOOT_READ) && xfer_state_boot && !xfer_pending && !busy;

always_comb begin
    case (state)
        SEND_CMD: tx_byte_boot = READ_CMD;
        SEND_ADDR: begin
            case (addr_idx)
                2'd0: tx_byte_boot = FLASH_BASE_ADDR[23:16];
                2'd1: tx_byte_boot = FLASH_BASE_ADDR[15:8];
                default: tx_byte_boot = FLASH_BASE_ADDR[7:0];
            endcase
        end
        default: tx_byte_boot = '0;
    endcase
end

always_comb begin
    next_state = state;
    if (bootloader_state == BOOT_READ) begin
        case (state)
            POWER_ON: begin
                if (wait_cntr == WAIT_W'(POWERUP_CYCLES-1))
                    next_state = CS_LOW;
            end
            CS_LOW:    next_state = SEND_CMD;
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
            DONE:    next_state = DONE;
            default: next_state = POWER_ON;
        endcase
    end
end

// =========================================================================
// FLASH_WRITE State Machine
// =========================================================================
typedef enum logic [3:0] {
    FW_IDLE,
    FW_START_PAGE,
    FW_WREN_CS_LOW,
    FW_WREN_CMD,
    FW_WREN_CS_HIGH,
    FW_PROG_CS_LOW,
    FW_PROG_CMD,
    FW_PROG_ADDR,
    FW_FETCH_WORD,
    FW_PROG_DATA,
    FW_PROG_CS_HIGH,
    FW_POLL_CS_LOW,
    FW_POLL_CMD,
    FW_POLL_READ,
    FW_POLL_CS_HIGH,
    FW_DONE
} fw_state_t;
fw_state_t fw_state;

logic [31:0] fw_bytes_written;
logic [31:0] fw_total_bytes;
logic [31:0] next_bytes_written;
logic [23:0] fw_prog_addr;
logic [23:0] fw_page_start_addr;
logic [1:0]  fw_addr_idx;
logic [31:0] mem_read_word;
logic [7:0]  status_reg;
logic [2:0]  delay_cntr;
logic [1:0]  fetch_cntr;
logic        cs_n_fw;
logic        fw_xfer_pending;
logic        fw_start;
logic        fw_xfer_state;
logic [FRAME_WIDTH-1:0] tx_byte_fw;

// Continuous assignment avoids parenthesized bit-slice in always_ff
assign next_bytes_written = fw_bytes_written + 1'b1;

assign fw_xfer_state = (fw_state == FW_WREN_CMD)  ||
                       (fw_state == FW_PROG_CMD)  ||
                       (fw_state == FW_PROG_ADDR) ||
                       (fw_state == FW_PROG_DATA) ||
                       (fw_state == FW_POLL_CMD)  ||
                       (fw_state == FW_POLL_READ);

assign fw_start = (bootloader_state == FLASH_WRITE) && fw_xfer_state && !fw_xfer_pending && !busy;

always_ff @(posedge spi_if.clk or negedge spi_if.rst_n) begin
    if (!spi_if.rst_n)
        fw_xfer_pending <= 1'b0;
    else if (fw_start)
        fw_xfer_pending <= 1'b1;
    else if (done)
        fw_xfer_pending <= 1'b0;
end

always_comb begin
    case (fw_state)
        FW_WREN_CMD:  tx_byte_fw = WRITE_EN_CMD;
        FW_PROG_CMD:  tx_byte_fw = PAGE_WRITE_CMD;
        FW_PROG_ADDR: begin
            case (fw_addr_idx)
                2'd0: tx_byte_fw = fw_page_start_addr[23:16];
                2'd1: tx_byte_fw = fw_page_start_addr[15:8];
                default: tx_byte_fw = fw_page_start_addr[7:0];
            endcase
        end
        FW_PROG_DATA: begin
            case (fw_bytes_written[1:0])
                2'b00: tx_byte_fw = mem_read_word[7:0];
                2'b01: tx_byte_fw = mem_read_word[15:8];
                2'b10: tx_byte_fw = mem_read_word[23:16];
                default: tx_byte_fw = mem_read_word[31:24];
            endcase
        end
        FW_POLL_CMD:  tx_byte_fw = STATUS_CMD;
        FW_POLL_READ: tx_byte_fw = 8'h00;
        default:      tx_byte_fw = 8'h00;
    endcase
end

always_ff @(posedge spi_if.clk or negedge spi_if.rst_n) begin
    if (!spi_if.rst_n) begin
        fw_state           <= FW_IDLE;
        fw_bytes_written   <= '0;
        fw_total_bytes     <= '0;
        fw_prog_addr       <= FLASH_BASE_ADDR;
        fw_page_start_addr <= FLASH_BASE_ADDR;
        fw_addr_idx        <= '0;
        mem_read_word      <= '0;
        status_reg         <= '0;
        delay_cntr         <= '0;
        fetch_cntr         <= '0;
        cs_n_fw            <= 1'b1;
        flash_write_done   <= 1'b0;
    end else begin
        case (fw_state)
            FW_IDLE: begin
                delay_cntr <= '0;
                fetch_cntr <= '0;
                cs_n_fw    <= 1'b1;
                if (bootloader_state == FLASH_WRITE) begin
                    flash_write_done   <= 1'b0;
                    fw_bytes_written   <= '0;
                    fw_prog_addr       <= FLASH_BASE_ADDR;
                    fw_total_bytes     <= (image_size != '0) ? image_size : DATA_WIDTH'(IMAGE_BYTES);
                    fw_state           <= FW_START_PAGE;
                end
            end

            FW_START_PAGE: begin
                cs_n_fw <= 1'b1;
                if (fw_bytes_written >= fw_total_bytes) begin
                    fw_state <= FW_DONE;
                end else begin
                    fw_state <= FW_WREN_CS_LOW;
                end
            end

            FW_WREN_CS_LOW: begin
                cs_n_fw  <= 1'b0;
                fw_state <= FW_WREN_CMD;
            end

            FW_WREN_CMD: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    fw_state   <= FW_WREN_CS_HIGH;
                    delay_cntr <= '0;
                end
            end

            // CS high deselect delay (t_SHSL)
            FW_WREN_CS_HIGH: begin
                cs_n_fw    <= 1'b1;
                delay_cntr <= delay_cntr + 1'b1;
                if (delay_cntr >= 3'd3) begin
                    fw_state           <= FW_PROG_CS_LOW;
                    fw_page_start_addr <= fw_prog_addr;
                end
            end

            FW_PROG_CS_LOW: begin
                cs_n_fw     <= 1'b0;
                fw_addr_idx <= 2'd0;
                fw_state    <= FW_PROG_CMD;
            end

            FW_PROG_CMD: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    fw_state    <= FW_PROG_ADDR;
                    fw_addr_idx <= 2'd0;
                end
            end

            FW_PROG_ADDR: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    if (fw_addr_idx == 2'd2) begin
                        fw_state   <= FW_FETCH_WORD;
                        fetch_cntr <= '0;
                    end else begin
                        fw_addr_idx <= fw_addr_idx + 1'b1;
                    end
                end
            end

            // Read 32-bit word from synchronous SRAM (accommodates 1-cycle RAM latency)
            FW_FETCH_WORD: begin
                cs_n_fw    <= 1'b0;
                fetch_cntr <= fetch_cntr + 1'b1;
                if (fetch_cntr == 2'd1) begin
                    mem_read_word <= mem_rdata;
                    fw_state      <= FW_PROG_DATA;
                    fetch_cntr    <= '0;
                end
            end

            FW_PROG_DATA: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    fw_bytes_written <= next_bytes_written;
                    fw_prog_addr     <= fw_prog_addr + 1'b1;

                    if (next_bytes_written >= fw_total_bytes) begin
                        fw_state   <= FW_PROG_CS_HIGH;
                        delay_cntr <= '0;
                    end else if (fw_prog_addr[7:0] == 8'hFF) begin
                        // 256-byte page boundary reached, must close current page
                        fw_state   <= FW_PROG_CS_HIGH;
                        delay_cntr <= '0;
                    end else if (next_bytes_written[1:0] == 2'b00) begin
                        // Need next word from SRAM
                        fw_state   <= FW_FETCH_WORD;
                        fetch_cntr <= '0;
                    end else begin
                        // Next byte is already in mem_read_word
                        fw_state <= FW_PROG_DATA;
                    end
                end
            end

            // CS high deselect delay triggers write in Flash chip
            FW_PROG_CS_HIGH: begin
                cs_n_fw    <= 1'b1;
                delay_cntr <= delay_cntr + 1'b1;
                if (delay_cntr >= 3'd3) begin
                    fw_state <= FW_POLL_CS_LOW;
                end
            end

            FW_POLL_CS_LOW: begin
                cs_n_fw  <= 1'b0;
                fw_state <= FW_POLL_CMD;
            end

            FW_POLL_CMD: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    fw_state <= FW_POLL_READ;
                end
            end

            FW_POLL_READ: begin
                cs_n_fw <= 1'b0;
                if (done) begin
                    status_reg <= rx_byte;
                    fw_state   <= FW_POLL_CS_HIGH;
                    delay_cntr <= '0;
                end
            end

            FW_POLL_CS_HIGH: begin
                cs_n_fw    <= 1'b1;
                delay_cntr <= delay_cntr + 1'b1;
                if (delay_cntr >= 3'd3) begin
                    if (status_reg[0] == 1'b1) begin
                        // WIP bit == 1: flash still programming, poll again
                        fw_state <= FW_POLL_CS_LOW;
                    end else begin
                        // WIP bit == 0: programming complete
                        if (fw_bytes_written >= fw_total_bytes) begin
                            fw_state <= FW_DONE;
                        end else begin
                            fw_state <= FW_START_PAGE;
                        end
                    end
                end
            end

            FW_DONE: begin
                cs_n_fw          <= 1'b1;
                flash_write_done <= 1'b1;
                fw_state         <= FW_IDLE;
            end

            default: fw_state <= FW_IDLE;
        endcase
    end
end

// =========================================================================
// Top-Level State and Handshaking
// =========================================================================
always_comb begin
    bootloader_next_state = bootloader_state;
    case (bootloader_state)
        BOOT_READ: begin
            if (state == DONE)
                bootloader_next_state = IDLE;
        end
        IDLE: begin
            if (flash_write_en)
                bootloader_next_state = FLASH_WRITE;
        end
        FLASH_WRITE: begin
            if (fw_state == FW_DONE && !flash_write_en)
                bootloader_next_state = IDLE;
        end
        default: bootloader_next_state = IDLE;
    endcase
end

always_ff @(posedge spi_if.clk or negedge spi_if.rst_n) begin
    if (!spi_if.rst_n) begin
        state            <= POWER_ON;
        bootloader_state <= BOOT_READ;
        wait_cntr        <= '0;
        addr_idx         <= '0;
        byte_cntr        <= '0;
        xfer_pending     <= 1'b0;
        cs_n_boot        <= 1'b1;
        boot_done        <= 1'b0;
    end else begin
        bootloader_state <= bootloader_next_state;
        if (start_boot)
            xfer_pending <= 1'b1;
        else if (done)
            xfer_pending <= 1'b0;

        case (bootloader_state)
            BOOT_READ: begin
                state <= next_state;

                case (state)
                    POWER_ON: wait_cntr <= wait_cntr + 1'b1;
                    CS_LOW:   cs_n_boot <= 1'b0;
                    SEND_ADDR: begin
                        if (done)
                            addr_idx <= addr_idx + 1'b1;
                    end
                    WRITE_BYTE: byte_cntr <= byte_cntr + 1'b1;
                    CS_HIGH: begin
                        cs_n_boot <= 1'b1;
                        boot_done <= 1'b1;
                    end
                    default: ;
                endcase
            end
            default: ;
        endcase
    end
end

// Multiplex shared SPI signals
assign spi_if.cs_n = (bootloader_state == BOOT_READ) ? cs_n_boot : cs_n_fw;
assign start        = (bootloader_state == BOOT_READ) ? start_boot : fw_start;
assign tx_byte      = (bootloader_state == BOOT_READ) ? tx_byte_boot : tx_byte_fw;

// Memory interface multiplexing
always_comb begin
    if (bootloader_state == BOOT_READ) begin
        mem_we    = (state == WRITE_BYTE);
        mem_addr  = ADDR_WIDTH'(byte_cntr);
        mem_wdata = {(DATA_WIDTH/FRAME_WIDTH){rx_byte}};
        mem_wmask = 4'b0001 << byte_cntr[1:0];
    end else if (bootloader_state == FLASH_WRITE) begin
        mem_we    = 1'b0;
        mem_addr  = ADDR_WIDTH'(fw_bytes_written);
        mem_wdata = '0;
        mem_wmask = 4'b0000;
    end else begin
        mem_we    = 1'b0;
        mem_addr  = '0;
        mem_wdata = '0;
        mem_wmask = 4'b0000;
    end
end

endmodule