`timescale 1ns/1ps

module system_test;
  logic clk;
  logic rst_n;

  system dut (
           .clk(clk),
           .rst_n(rst_n)
         );

  // Clock Generation
  initial
    clk = 0;
  always #5 clk = ~clk;

  initial
  begin
    // load test_program.hex
    $readmemh("test_program.hex", dut.rom.rom);
    // vcd dump
    $dumpfile("system_test.vcd");
    $dumpvars(0, system_test);
    // reset
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (10) @(posedge clk);
    // result
    $display("x1 = %0d (expect 5)", dut.u_register_file.registers[1]);

    $finish;
  end

endmodule
