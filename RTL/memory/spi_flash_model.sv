/*
SPI Flash model for Simulation

SPI mode 0, MSB first: sample mosi on posedge sclk, change miso on negedge sclk.
One transaction = one cs_n low window.
Commands:
    0x03  READ   cmd | A[23:16] | A[15:8] | A[7:0] | D0 D1 ...
    0x02  WRITE  cmd | A[23:16] | A[15:8] | A[7:0] | D0 D1 ...
    anything else is ignored until cs_n goes high
*/
`timescale 1ns/1ps

module spi_flash_model #(
    parameter int MEM_BYTES = 8192,
    parameter int WL = 8,
    parameter int ADDR_W = $clog2(MEM_BYTES),
    parameter string INIT_FILE = "", 
    parameter string DUMP_FILE = ""  
)(
    input  logic sclk,
    input  logic mosi,
    input  logic cs_n,
    output logic miso
);

localparam logic [WL-1:0] CMD_READ       = 8'h03;
localparam logic [WL-1:0] CMD_WRITE      = 8'h02;
localparam logic [WL-1:0] CMD_WRITE_EN   = 8'h06;
localparam logic [WL-1:0] CMD_RD_STATUS  = 8'h05;

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
        // Cast to 8-bit to ensure proper 24-bit width and 256-byte page wrap
        live_addr = ADDR_W'({flash_addr_reg[23:8], 8'(flash_addr_reg[7:0] + (byte_cnt - 4))});
    end else begin
        live_addr = ADDR_W'(flash_addr_reg + (byte_cnt - 4));
    end
end

always @(posedge sclk) begin
    if (!cs_n) begin
        rx_byte <= rx_next;
        bit_cnt <= bit_cnt + 1;
        
        if (bit_cnt == WL-1) begin
            case (byte_cnt)
                0: begin
                    cmd <= rx_next;
                    if (rx_next == CMD_WRITE_EN) wel_bit <= 1'b1;
                end
                1: flash_addr_reg[23:16] <= rx_next;
                2: flash_addr_reg[15:8]  <= rx_next;
                3: flash_addr_reg[7:0]   <= rx_next;
                default: begin
                    if (cmd == CMD_WRITE && wel_bit) begin
                        mem[live_addr] <= rx_next;
                        wip_bit        <= 1'b1; 
                    end
                end
            endcase
            byte_cnt <= byte_cnt + 1;
            bit_cnt  <= 0;
        end
    end
end

always @(negedge sclk) begin
    if (!cs_n) begin
        if (bit_cnt == 0) begin
            if (cmd == CMD_RD_STATUS) begin
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

always @(posedge cs_n) begin
    if (cmd == CMD_WRITE) begin
        wel_bit <= 1'b0; 
        wip_bit <= #50 1'b0; 
    end
end

final begin
    if (DUMP_FILE != "") begin
        $writememh(DUMP_FILE, mem);
    end
end

endmodule