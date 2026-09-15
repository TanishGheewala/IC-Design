`timescale 1ns/1ps

module core_test_base;
  logic clk;
  logic rst_n;

  core_interface core_if();

  core #(
          .ROM_INITIAL_FILE("test_program.hex"),
          .DEBUG_PRINT(1'b1)
        )
    core_dut(.core_if(core_if.dut));

  // Clock Generation
  initial
    clk = 0;
  always #5 clk = ~clk;

  assign core_if.clk = clk;
  assign core_if.core_halt = 1'b0;

  initial
  begin
    // vcd dump
    $dumpfile("core_test_base.vcd");
    $dumpvars(0, core_test_base);
    // reset
    core_if.rst_n = 0;
    repeat (2) @(posedge clk);
    core_if.rst_n = 1;
    repeat (4) @(posedge clk);
    // result
    $display("x1 = %0d (expect 5)", core_dut.u_register_file.registers[1]);

    $finish;
  end

endmodule