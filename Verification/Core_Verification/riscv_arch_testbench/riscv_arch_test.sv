`timescale 1ns/1ps

module riscv_arch_test_tb;

  localparam int ADDR_WIDTH = 20;
  localparam int MEM_DEPTH = 262144;
  localparam int MAX_CYCLES = 1000000;

  localparam logic [31:0] TEST_STATUS_ADDR = 32'h000F_F000;
  localparam string TEST_HEX = "I-add-00.hex";

  logic clk;
  logic rst_n;
  int unsigned cycle_counter;

  system #(
           .ADDR_WIDTH(ADDR_WIDTH),
           .MEM_DEPTH(MEM_DEPTH),
           .ROM_INITIAL_FILE(TEST_HEX),
           .RAM_INITIAL_FILE(TEST_HEX),
           .DEBUG_PRINT(1'b0)
         ) dut (
           .clk(clk),
           .rst_n(rst_n)
         );

  initial
    clk = 0;
  always #5 clk = ~clk;

  initial
  begin
    rst_n = 0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1;
  end

  always_ff @(posedge clk)
  begin
    if (!rst_n)
      cycle_counter <= 0;
    else
    begin
      cycle_counter <= cycle_counter + 1;

      if (dut.dec_if.mem_write &&
          (dut.alu_if.out_data == TEST_STATUS_ADDR))
      begin
        if (dut.ram_if.data_in == 32'd1)
          $display("RVCP-SUMMARY: TEST PASSED");
        else if (dut.ram_if.data_in == 32'd3)
          $display("RVCP-SUMMARY: TEST FAILED");
        else
          $display("RVCP-SUMMARY: INVALID TEST STATUS");

        $finish;
      end

      if (cycle_counter >= MAX_CYCLES)
      begin
        $display("RVCP-SUMMARY: TEST TIMED OUT");
        $finish;
      end
    end
  end

endmodule