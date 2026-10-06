// 8KB Single-Port SRAM wrapper
// 4 * 2KB SRAM Macros

`include "macros.vh"

module data_memory_sram8k
  #(
     parameter ADDR_WIDTH = 13, // byte address width -> 2048 words x 4B = 8KB
     parameter DATA_WIDTH = `DATA_WIDTH, // 32
     parameter MEM_DEPTH  = 2048 // 2048 words = 8KB
   )(
     input  clk,
     input  we,
     input  [ADDR_WIDTH-1:0] addr, // byte address
     input  [DATA_WIDTH-1:0] data_in,
     output [DATA_WIDTH-1:0] data_out // 1-cycle latency
   );

  wire [10:0] word_addr = addr[ADDR_WIDTH-1:2]; // 11 bits -> 2048 words
  wire [1:0]  bank_sel  = word_addr[10:9]; // picks bank (0-3)
  wire [8:0]  bank_addr = word_addr[8:0]; // within-bank addr (0-511)
  reg [1:0] bank_sel_q;
  always @(posedge clk)
  begin
    bank_sel_q <= bank_sel;
  end

  wire [3:0] wmask = {4{we}}; // whole-word write enable (4 bytes)

  wire csb0_0 = (bank_sel == 2'd0) ? 1'b0 : 1'b1;
  wire csb0_1 = (bank_sel == 2'd1) ? 1'b0 : 1'b1;
  wire csb0_2 = (bank_sel == 2'd2) ? 1'b0 : 1'b1;
  wire csb0_3 = (bank_sel == 2'd3) ? 1'b0 : 1'b1;

  wire [DATA_WIDTH-1:0] dout0_0, dout0_1, dout0_2, dout0_3;

  sky130_sram_2kbyte_1rw1r_32x512_8 bank0 (
                                      .clk0(clk), .csb0(csb0_0), .web0(~we), .wmask0(wmask),
                                      .addr0(bank_addr), .din0(data_in), .dout0(dout0_0),
                                      .clk1(clk), .csb1(1'b1), .addr1(bank_addr), .dout1()
                                    );
  sky130_sram_2kbyte_1rw1r_32x512_8 bank1 (
                                      .clk0(clk), .csb0(csb0_1), .web0(~we), .wmask0(wmask),
                                      .addr0(bank_addr), .din0(data_in), .dout0(dout0_1),
                                      .clk1(clk), .csb1(1'b1), .addr1(bank_addr), .dout1()
                                    );
  sky130_sram_2kbyte_1rw1r_32x512_8 bank2 (
                                      .clk0(clk), .csb0(csb0_2), .web0(~we), .wmask0(wmask),
                                      .addr0(bank_addr), .din0(data_in), .dout0(dout0_2),
                                      .clk1(clk), .csb1(1'b1), .addr1(bank_addr), .dout1()
                                    );
  sky130_sram_2kbyte_1rw1r_32x512_8 bank3 (
                                      .clk0(clk), .csb0(csb0_3), .web0(~we), .wmask0(wmask),
                                      .addr0(bank_addr), .din0(data_in), .dout0(dout0_3),
                                      .clk1(clk), .csb1(1'b1), .addr1(bank_addr), .dout1()
                                    );

  reg [DATA_WIDTH-1:0] data_out_r;
  always @(*)
  begin
    case (bank_sel_q)
      2'd0:
        data_out_r = dout0_0;
      2'd1:
        data_out_r = dout0_1;
      2'd2:
        data_out_r = dout0_2;
      default:
        data_out_r = dout0_3;
    endcase
  end
  assign data_out = data_out_r;

endmodule
