`timescale 1ns/1ps

module spi_flash_model #(
    parameter int MEM_BYTES    = 8192,
    parameter string INIT_FILE = ""
)(
    input  logic clk,       // 50 MHz system clock (shared with SoC)
    input  logic rst_n,     // Active-low reset for control logic
    input  logic sclk,      // SPI SCLK from SoC (supports up to clk/4 = 12.5 MHz)
    input  logic mosi,      // SPI MOSI from SoC
    input  logic cs_n,      // SPI CS_N from SoC
    output logic miso       // SPI MISO to SoC
);

    // Standard SPI Flash Opcodes
    localparam logic [7:0] CMD_READ          = 8'h03;
    localparam logic [7:0] CMD_WRITE         = 8'h02; // Page Program
    localparam logic [7:0] CMD_WREN          = 8'h06; // Write Enable
    localparam logic [7:0] CMD_WRDI          = 8'h04; // Write Disable
    localparam logic [7:0] CMD_RDSR          = 8'h05; // Read Status Register
    localparam logic [7:0] CMD_SECTOR_ERASE  = 8'h20; // 4KB Sector Erase
    localparam logic [7:0] CMD_CHIP_ERASE_C7 = 8'hC7;
    localparam logic [7:0] CMD_CHIP_ERASE_60 = 8'h60;

    localparam int ADDR_BITS = $clog2(MEM_BYTES);
    localparam int MEM_DEPTH = 1 << ADDR_BITS;
    localparam logic [ADDR_BITS-1:0] SECTOR_MASK = ~ADDR_BITS'(12'hFFF);

    // =========================================================================
    // 1. DEDICATED XILINX UG901 BRAM TEMPLATE (NO ASYNC RESET)
    // =========================================================================
    (* ram_style = "block" *)
    logic [7:0] mem [0:MEM_DEPTH-1];

    initial begin
        for (int i = 0; i < MEM_DEPTH; i++) begin
            mem[i] = 8'hFF;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    logic                 bram_we;
    logic [ADDR_BITS-1:0] bram_waddr;
    logic [7:0]           bram_wdata;
    logic [ADDR_BITS-1:0] bram_raddr;
    logic [7:0]           bram_rdata;

    // Pure synchronous Simple Dual-Port RAM (Port A: Write, Port B: Read)
    always_ff @(posedge clk) begin
        if (bram_we) begin
            mem[bram_waddr] <= bram_wdata;
        end
        bram_rdata <= mem[bram_raddr];
    end

    // =========================================================================
    // 2. SYNCHRONOUS EDGE DETECTION (Same clk domain as SoC)
    // =========================================================================
    logic sclk_d1;
    logic cs_n_d1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_d1 <= 1'b0;
            cs_n_d1 <= 1'b1;
        end else begin
            sclk_d1 <= sclk;
            cs_n_d1 <= cs_n;
        end
    end

    wire sclk_rising   = (sclk && !sclk_d1);
    wire sclk_falling  = (!sclk && sclk_d1);
    wire cs_active     = !cs_n;
    wire cs_deasserted = (cs_n && !cs_n_d1); // Rising edge of CS_N

    // =========================================================================
    // 3. CONTROL & STATUS REGISTERS
    // =========================================================================
    logic wel_bit;
    logic erase_active;
    logic [ADDR_BITS-1:0] erase_addr;
    logic [ADDR_BITS-1:0] erase_end;

    wire wip_bit = erase_active;
    wire [7:0] status_reg = {6'b000000, wel_bit, wip_bit};

    logic [7:0]  cmd_reg;
    logic [23:0] addr_reg;
    logic [7:0]  shift_rx;
    logic [7:0]  shift_tx;
    logic [2:0]  bit_cnt;
    logic [2:0]  byte_cnt; // Saturates at 4 (Cmd + 3 Addr bytes)
    logic        miso_reg;

    logic                 spi_we;
    logic [ADDR_BITS-1:0] spi_waddr;
    logic [7:0]           spi_wdata;

    // Multiplex the single write port between Erase and SPI Page Write
    assign bram_we    = erase_active ? 1'b1       : spi_we;
    assign bram_waddr = erase_active ? erase_addr : spi_waddr;
    assign bram_wdata = erase_active ? 8'hFF      : spi_wdata;

    wire [7:0] rx_byte_complete = {shift_rx[6:0], mosi};

    // =========================================================================
    // 4. SEQUENTIAL HARDWARE ERASE FSM (1 byte/cycle)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            erase_active <= 1'b0;
            erase_addr   <= '0;
            erase_end    <= '0;
        end else begin
            if (erase_active) begin
                if (erase_addr >= erase_end) begin
                    erase_active <= 1'b0;
                end else begin
                    erase_addr <= erase_addr + 1'b1;
                end
            end else if (cs_deasserted && wel_bit) begin
                // Sector Erase (4KB)
                if (cmd_reg == CMD_SECTOR_ERASE && byte_cnt >= 3'd4) begin
                    erase_active <= 1'b1;
                    erase_addr   <= addr_reg[ADDR_BITS-1:0] & SECTOR_MASK;
                    erase_end    <= (addr_reg[ADDR_BITS-1:0] & SECTOR_MASK) | ADDR_BITS'(12'hFFF);
                end
                // Chip Erase
                else if ((cmd_reg == CMD_CHIP_ERASE_C7 || cmd_reg == CMD_CHIP_ERASE_60) && byte_cnt >= 3'd1) begin
                    erase_active <= 1'b1;
                    erase_addr   <= '0;
                    erase_end    <= ADDR_BITS'(MEM_BYTES - 1);
                end
            end
        end
    end

    // =========================================================================
    // 5. SPI PROTOCOL ENGINE (SPI Mode 0)
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_reg    <= 8'h00;
            addr_reg   <= 24'h0;
            shift_rx   <= 8'h00;
            shift_tx   <= 8'h00;
            bit_cnt    <= 3'd0;
            byte_cnt   <= 3'd0;
            wel_bit    <= 1'b0;
            miso_reg   <= 1'b0;
            spi_we     <= 1'b0;
            spi_waddr  <= '0;
            spi_wdata  <= 8'h00;
            bram_raddr <= '0;
        end else begin
            spi_we <= 1'b0; // Default: 1-cycle write pulse

            if (cs_deasserted) begin
                cmd_reg  <= 8'h00;
                bit_cnt  <= 3'd0;
                byte_cnt <= 3'd0;
                miso_reg <= 1'b0;

                if ((cmd_reg == CMD_WRITE && byte_cnt >= 3'd4) ||
                    (cmd_reg == CMD_SECTOR_ERASE && byte_cnt >= 3'd4) ||
                    ((cmd_reg == CMD_CHIP_ERASE_C7 || cmd_reg == CMD_CHIP_ERASE_60) && byte_cnt >= 3'd1)) begin
                    wel_bit <= 1'b0;
                end
            end else if (cs_active) begin
                // SCLK Rising Edge: Sample MOSI & execute byte transfers
                if (sclk_rising) begin
                    shift_rx <= rx_byte_complete;
                    bit_cnt  <= bit_cnt + 1'b1;

                    if (bit_cnt == 3'd7) begin
                        bit_cnt <= 3'd0;
                        if (byte_cnt < 3'd4) begin
                            byte_cnt <= byte_cnt + 1'b1;
                        end

                        if (byte_cnt == 3'd0) begin
                            cmd_reg <= rx_byte_complete;
                            if (!erase_active) begin
                                if (rx_byte_complete == CMD_WREN) wel_bit <= 1'b1;
                                if (rx_byte_complete == CMD_WRDI) wel_bit <= 1'b0;
                            end
                        end else if (byte_cnt == 3'd1) begin
                            addr_reg[23:16] <= rx_byte_complete;
                        end else if (byte_cnt == 3'd2) begin
                            addr_reg[15:8]  <= rx_byte_complete;
                        end else if (byte_cnt == 3'd3) begin
                            if (cmd_reg == CMD_READ) begin
                                bram_raddr <= {addr_reg[23:8], rx_byte_complete}[ADDR_BITS-1:0];
                                addr_reg   <= {addr_reg[23:8], rx_byte_complete} + 1'b1;
                            end else begin
                                addr_reg[7:0] <= rx_byte_complete;
                            end
                        end else begin
                            // Page Program Write (with 256-byte page wrap)
                            if (cmd_reg == CMD_WRITE && wel_bit && !erase_active) begin
                                spi_we    <= 1'b1;
                                spi_waddr <= addr_reg[ADDR_BITS-1:0];
                                spi_wdata <= rx_byte_complete;
                                addr_reg  <= {addr_reg[23:8], 8'(addr_reg[7:0] + 1'b1)};
                            end
                            // Read: Prefetch next sequential byte
                            else if (cmd_reg == CMD_READ) begin
                                bram_raddr <= addr_reg[ADDR_BITS-1:0];
                                addr_reg   <= addr_reg + 1'b1;
                            end
                        end
                    end
                end

                // SCLK Falling Edge: Drive MISO
                if (sclk_falling) begin
                    if (cmd_reg == CMD_RDSR && byte_cnt >= 3'd1) begin
                        if (bit_cnt == 3'd0) begin
                            miso_reg <= status_reg[7];
                            shift_tx <= {status_reg[6:0], 1'b0};
                        end else begin
                            miso_reg <= shift_tx[7];
                            shift_tx <= {shift_tx[6:0], 1'b0};
                        end
                    end else if (cmd_reg == CMD_READ && byte_cnt >= 3'd4) begin
                        if (bit_cnt == 3'd0) begin
                            miso_reg <= bram_rdata[7];
                            shift_tx <= {bram_rdata[6:0], 1'b0};
                        end else begin
                            miso_reg <= shift_tx[7];
                            shift_tx <= {shift_tx[6:0], 1'b0};
                        end
                    end else begin
                        miso_reg <= 1'b0;
                    end
                end
            end else begin
                miso_reg <= 1'b0;
            end
        end
    end

    // Drive 0 instead of 1'bz to avoid internal FPGA tri-state warnings
    assign miso = miso_reg;

endmodule