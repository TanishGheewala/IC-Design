// Testbench for data_memory_sram8k.v

`timescale 1ns/1ps

module tb_sram8k;

  reg clk = 0;
  reg we;
  reg [12:0] addr;
  reg [31:0] data_in;
  wire [31:0] data_out;

  integer errors = 0;

  data_memory_sram8k dut (
                       .clk(clk),
                       .we(we),
                       .addr(addr),
                       .data_in(data_in),
                       .data_out(data_out)
                     );

  always #5 clk = ~clk;

  task write_word(input [12:0] a, input [31:0] d);
    begin
      @(negedge clk);
      we = 1;
      addr = a;
      data_in = d;
      @(negedge clk);
      we = 0;
    end
  endtask

  task read_check(input [12:0] a, input [31:0] expected);
    begin
      @(negedge clk);
      we = 0;
      addr = a;
      @(posedge clk);
      @(posedge clk);
      if (data_out !== expected)
      begin
        $display("FAIL: addr=%0h expected=%h got=%h", a, expected, data_out);
        errors = errors + 1;
      end
      else
      begin
        $display("PASS: addr=%0h data=%h", a, data_out);
      end
    end
  endtask

  initial
  begin
    we = 0;
    addr = 0;
    data_in = 0;
    repeat (3) @(negedge clk);

    write_word(13'h0000, 32'hAAAA_0000); // bank0, word 0
    write_word(13'h0004, 32'hAAAA_0001); // bank0, word 1
    write_word(13'h0800, 32'hBBBB_0000); // bank1, word 0 (word_addr 512)
    write_word(13'h1000, 32'hCCCC_0000); // bank2, word 0 (word_addr 1024)
    write_word(13'h1800, 32'hDDDD_0000); // bank3, word 0 (word_addr 1536)
    write_word(13'h1FFC, 32'hDDDD_FFFF); // bank3, last word (word_addr 2047)
    read_check(13'h0000, 32'hAAAA_0000);
    read_check(13'h0004, 32'hAAAA_0001);
    read_check(13'h0800, 32'hBBBB_0000);
    read_check(13'h1000, 32'hCCCC_0000);
    read_check(13'h1800, 32'hDDDD_0000);
    read_check(13'h1FFC, 32'hDDDD_FFFF);
    read_check(13'h0000, 32'hAAAA_0000);
    read_check(13'h1800, 32'hDDDD_0000);
    read_check(13'h0800, 32'hBBBB_0000);
    read_check(13'h1000, 32'hCCCC_0000);

    if (errors == 0)
      $display("\n*** ALL CHECKS PASSED ***");
    else
      $display("\n*** %0d CHECK(S) FAILED ***", errors);

    $finish;
  end

endmodule
