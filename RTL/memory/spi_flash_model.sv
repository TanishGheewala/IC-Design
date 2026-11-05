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
    parameter string INIT_FILE = "", //file to read from
    parameter string DUMP_FILE = ""  //file to write to
)(
    input  logic sclk,
    input  logic mosi,
    input  logic cs_n,
    output logic miso
);

localparam logic [WL-1:0] CMD_READ  = 8'h03;
localparam logic [WL-1:0] CMD_WRITE = 8'h02;

logic [WL-1:0]  mem [0:MEM_BYTES-1];

logic [WL-1:0]  rx_byte;
logic [WL-1:0]  tx_byte;
int bit_cnt; //0..WL-1 inside the current byte
int byte_cnt; //bytes since cs_n fell: 0 = cmd, 1-3 = address, 4+ = data
logic [WL-1:0]  cmd;

initial miso = 1'b0;

//initial: fill mem with 8'hFF
initial begin
    mem = '{default: 8'hFF};
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end

//negedge cs_n: bit_cnt = 0, byte_cnt = 0
always @(negedge cs_n) begin
    bit_cnt <= 0;
    byte_cnt <= 0;
end

logic [WL-1:0] rx_next;
logic [3*WL-1:0] addr_full;
assign rx_next = {rx_byte[WL-2:0], mosi};

//data_addr: address of the current data byte, start address + data bytes already done
logic [ADDR_W-1:0] data_addr;
assign data_addr = addr_full[ADDR_W-1:0] + ADDR_W'(byte_cnt - 4); //only used when byte_cnt >= 4

//  shift mosi into rx_byte, bit count ++
//    byte 0      -> cmd = rx_next
//    bytes 1..3  -> shift rx_next into addr_full
//    bytes 4+    -> WRITE: mem[data_addr] = rx_next
always @(posedge sclk) begin
    if (!cs_n) begin
        rx_byte <= rx_next;
        bit_cnt <= bit_cnt + 1;
        if (bit_cnt == WL-1) begin
            case (byte_cnt)
                0: cmd <= rx_next;
                1,2,3: addr_full <= {addr_full[2*WL-1:0], rx_next};
                default: if (cmd == CMD_WRITE) begin
                    mem[data_addr] <= rx_next;
                end
            endcase
            byte_cnt <= byte_cnt + 1;
            bit_cnt <= 0;
        end
    end
end

//  READ, data phase: drive tx_byte MSB first on miso
always @(negedge sclk) begin
    if (!cs_n) begin
        if (cmd == CMD_READ && byte_cnt >= 4 && bit_cnt == 0) begin
            miso <= mem[data_addr][WL-1];
            tx_byte <= {mem[data_addr][WL-2:0], 1'b0};
        end else begin
            miso <= tx_byte[WL-1];
            tx_byte <= {tx_byte[WL-2:0], 1'b0};
        end
    end
end

//dump memory contents at the end of the sim
final begin
    if (DUMP_FILE != "") begin
        $writememh(DUMP_FILE, mem);
    end
end
endmodule
