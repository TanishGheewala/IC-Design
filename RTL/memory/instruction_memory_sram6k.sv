// 6KB Single-Port SRAM wrapper
// 3 x 2KB SRAM macros

`include "macros.vh"

module instruction_memory_sram6k
#(
    parameter ADDR_WIDTH = 13,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter MEM_DEPTH  = 2048
) (
    input                       clk,
    input                       we,
    input      [3:0]            wmask,
    input      [ADDR_WIDTH-1:0] addr,
    input      [DATA_WIDTH-1:0] data_in,
    output     [DATA_WIDTH-1:0] data_out
);

    logic [10:0] word_addr;
    logic [1:0]  bank_sel;
    logic [8:0]  bank_addr;
    logic [1:0] bank_sel_q;
    logic csb0_0;
    logic csb0_1;
    logic csb0_2;

    always_ff @(posedge clk) begin
        bank_sel_q <= bank_sel;
    end
    
    always_comb begin
      word_addr = addr[ADDR_WIDTH-1:2];
      bank_sel  = word_addr[10:9];
      bank_addr = word_addr[8:0]; 
      csb0_0 = (bank_sel == 2'd0) ? 1'b0 : 1'b1;
      csb0_1 = (bank_sel == 2'd1) ? 1'b0 : 1'b1;
      csb0_2 = (bank_sel == 2'd2) ? 1'b0 : 1'b1;
    end

    logic [DATA_WIDTH-1:0] dout0_0;
    logic [DATA_WIDTH-1:0] dout0_1;
    logic [DATA_WIDTH-1:0] dout0_2;

    sky130_sram_2kbyte_1rw1r_32x512_8 #(
        .VERBOSE(0)
        ) bank0 (
            .clk0(clk),
            .csb0(csb0_0),
            .web0(~we),
            .wmask0(wmask),
            .addr0(bank_addr),
            .din0(data_in),
            .dout0(dout0_0),
            .clk1(clk),
            .csb1(1'b1),
            .addr1(bank_addr),
            .dout1()
    );

    sky130_sram_2kbyte_1rw1r_32x512_8 #(
        .VERBOSE(0)
        ) bank1 (
            .clk0(clk),
            .csb0(csb0_1),
            .web0(~we),
            .wmask0(wmask),
            .addr0(bank_addr),
            .din0(data_in),
            .dout0(dout0_1),
            .clk1(clk),
            .csb1(1'b1),
            .addr1(bank_addr),
            .dout1()
    );

    sky130_sram_2kbyte_1rw1r_32x512_8 #(
        .VERBOSE(0)
        ) bank2 (
            .clk0(clk),
            .csb0(csb0_2),
            .web0(~we),
            .wmask0(wmask),
            .addr0(bank_addr),
            .din0(data_in),
            .dout0(dout0_2),
            .clk1(clk),
            .csb1(1'b1),
            .addr1(bank_addr),
            .dout1()
    );

    logic [DATA_WIDTH-1:0] data_out_r;

    always_comb begin
      case (bank_sel_q)
          2'd0: data_out_r = dout0_0;

          2'd1: data_out_r = dout0_1;

          default: data_out_r = dout0_2;
      endcase
    end

    assign data_out = data_out_r;

endmodule
