/*
SPI Flash Model for Simulation (with Erase Support)

SPI mode 0, MSB first: sample mosi on posedge sclk, change miso on negedge sclk.
One transaction = one cs_n low window.

Supported Commands:
    0x03  READ         cmd | A[23:16] | A[15:8] | A[7:0] | D0 D1 ...
    0x02  PAGE WRITE   cmd | A[23:16] | A[15:8] | A[7:0] | D0 D1 ...
    0x06  WRITE EN     cmd
    0x04  WRITE DIS    cmd
    0x05  RD STATUS    cmd | S[7:0] ... (bit 1: WEL, bit 0: WIP)
    0xC7  CHIP ERASE   cmd (erases entire memory to 0xFF)
    0x60  CHIP ERASE   cmd (alternative opcode)
    0x20  SECTOR ERASE cmd | A[23:16] | A[15:8] | A[7:0] (erases 4KB sector)
    0xD8  BLOCK ERASE  cmd | A[23:16] | A[15:8] | A[7:0] (erases 64KB block)
*/
`timescale 1ns/1ps

module spi_flash_model #(
    parameter int MEM_BYTES     = 8192,
    parameter int WL            = 8,
    parameter int ADDR_W        = $clog2(MEM_BYTES),
    parameter string INIT_FILE  = "", 
    parameter string DUMP_FILE  = "",
    parameter int PROG_TIME_NS  = 50,  // Simulated page programming delay
    parameter int ERASE_TIME_NS = 200  // Simulated erase delay (keep small for fast sim)
)(
    input  logic sclk,
    input  logic mosi,
    input  logic cs_n,
    output logic miso
);

// Standard SPI Flash Command Opcodes
localparam logic [WL-1:0] CMD_READ          = 8'h03;
localparam logic [WL-1:0] CMD_WRITE         = 8'h02;
localparam logic [WL-1:0] CMD_WRITE_EN      = 8'h06;
localparam logic [WL-1:0] CMD_WRITE_DIS     = 8'h04;
localparam logic [WL-1:0] CMD_RD_STATUS     = 8'h05;
localparam logic [WL-1:0] CMD_CHIP_ERASE_C7 = 8'hC7;
localparam logic [WL-1:0] CMD_CHIP_ERASE_60 = 8'h60;
localparam logic [WL-1:0] CMD_SECTOR_ERASE  = 8'h20; // 4 KB
localparam logic [WL-1:0] CMD_BLOCK_ERASE   = 8'hD8; // 64 KB

logic [WL-1:0]  mem [0:MEM_BYTES-1];

logic [WL-1:0]  rx_byte;
logic [WL-1:0]  tx_byte;
int bit_cnt; 
int byte_cnt; 
logic [WL-1:0]  cmd;
logic [23:0]    flash_addr_reg; 
logic           wel_bit;        
logic           wip_bit; 

initial miso = 1'b0;

initial begin
    mem = '{default: 8'hFF};
    wel_bit = 1'b0;
    wip_bit = 1'b0;
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end

always @(negedge cs_n) begin
    bit_cnt  <= 0;
    byte_cnt <= 0;
    cmd      <= '0;
end

logic [WL-1:0] rx_next;
assign rx_next = {rx_byte[WL-2:0], mosi};

logic [ADDR_W-1:0] live_addr;
always_comb begin
    if (cmd == CMD_WRITE) begin
        // 256-byte page wrap
        live_addr = ADDR_W'({flash_addr_reg[23:8], 8'(flash_addr_reg[7:0] + (byte_cnt - 4))});
    end else begin
        live_addr = ADDR_W'(flash_addr_reg + (byte_cnt - 4));
    end
end

// =========================================================================
// Sample MOSI on posedge SCLK
// =========================================================================
always @(posedge sclk) begin
    if (!cs_n) begin
        rx_byte <= rx_next;
        bit_cnt <= bit_cnt + 1;
        
        if (bit_cnt == WL-1) begin
            case (byte_cnt)
                0: begin
                    cmd <= rx_next;
                    if (rx_next == CMD_WRITE_EN)  wel_bit <= 1'b1;
                    if (rx_next == CMD_WRITE_DIS) wel_bit <= 1'b0;
                end
                1: flash_addr_reg[23:16] <= rx_next;
                2: flash_addr_reg[15:8]  <= rx_next;
                3: flash_addr_reg[7:0]   <= rx_next;
                default: begin
                    // Real NOR Flash physical property: can only pull bits from 1 -> 0
                    if (cmd == CMD_WRITE && wel_bit) begin
                        mem[live_addr] <= mem[live_addr] & rx_next;
                        wip_bit        <= 1'b1; 
                    end
                end
            endcase
            byte_cnt <= byte_cnt + 1;
            bit_cnt  <= 0;
        end
    end
end

// =========================================================================
// Drive MISO on negedge SCLK
// =========================================================================
always @(negedge sclk) begin
    if (!cs_n) begin
        if (bit_cnt == 0) begin
            if (cmd == CMD_RD_STATUS) begin
                // Status Register: [1] = WEL, [0] = WIP
                tx_byte <= {6'b000000, wel_bit, wip_bit}; 
                miso    <= 1'b0; 
            end else if (cmd == CMD_READ && byte_cnt >= 4) begin
                miso    <= mem[live_addr][WL-1];
                tx_byte <= {mem[live_addr][WL-2:0], 1'b0};
            end else begin
                miso    <= tx_byte[WL-1];
                tx_byte <= {tx_byte[WL-2:0], 1'b0};
            end
        end else begin
            miso    <= tx_byte[WL-1];
            tx_byte <= {tx_byte[WL-2:0], 1'b0};
        end
    end
end

// =========================================================================
// Execute Operations on posedge CS_N (Commit Point)
// =========================================================================
always @(posedge cs_n) begin
    // ---------------- PAGE WRITE ----------------
    if (cmd == CMD_WRITE && wel_bit && byte_cnt >= 4) begin
        wel_bit <= 1'b0;
        wip_bit <= 1'b1;
        wip_bit <= #(PROG_TIME_NS) 1'b0;
    end

    // ---------------- CHIP ERASE (0xC7 / 0x60) ----------------
    else if ((cmd == CMD_CHIP_ERASE_C7 || cmd == CMD_CHIP_ERASE_60) && wel_bit && byte_cnt >= 1) begin
        wel_bit <= 1'b0;
        wip_bit <= 1'b1;
        wip_bit <= #(ERASE_TIME_NS) 1'b0;
        
        // Reset all bytes in array to 0xFF
        for (int i = 0; i < MEM_BYTES; i++) begin
            mem[i] = 8'hFF;
        end
    end

    // ---------------- 4KB SECTOR ERASE (0x20) ----------------
    else if (cmd == CMD_SECTOR_ERASE && wel_bit && byte_cnt >= 4) begin
        int sector_start;
        wel_bit <= 1'b0;
        wip_bit <= 1'b1;
        wip_bit <= #(ERASE_TIME_NS) 1'b0;
        
        sector_start = flash_addr_reg & ~24'h00_0FFF; // Align to 4KB
        for (int i = 0; i < 4096; i++) begin
            if ((sector_start + i) < MEM_BYTES) begin
                mem[sector_start + i] = 8'hFF;
            end
        end
    end

    // ---------------- 64KB BLOCK ERASE (0xD8) ----------------
    else if (cmd == CMD_BLOCK_ERASE && wel_bit && byte_cnt >= 4) begin
        int block_start;
        wel_bit <= 1'b0;
        wip_bit <= 1'b1;
        wip_bit <= #(ERASE_TIME_NS) 1'b0;
        
        block_start = flash_addr_reg & ~24'h00_FFFF; // Align to 64KB
        for (int i = 0; i < 65536; i++) begin
            if ((block_start + i) < MEM_BYTES) begin
                mem[block_start + i] = 8'hFF;
            end
        end
    end
end

final begin
    if (DUMP_FILE != "") begin
        $writememh(DUMP_FILE, mem);
    end
end

endmodule