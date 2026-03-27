/*
* tb_top is the top level testbench for our prototype
*/

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*; 


module tb_top;

  //imports custom classes
  import alu_pkg::*;

  // 1. Interface Instantiation
  clk_interface clk_if(); 
  alu_interface alu_if();

  // 2. DUT Instantiation
  alu DUT (
    .alu_if(alu_if.alu_dut)
  );

  // 3. UVM Configuration and Test Execution
  initial begin
    uvm_config_db#(virtual alu_interface)::set(null, "*", "alu_interface", alu_if);
    uvm_config_db#(virtual clk_interface)::set(null, "*", "clk_interface", clk_if);

    $display("===============================================================");
    $display(" Starting UVM Simulation for ALU Prototype                     ");
    $display("===============================================================");

    // Run the specific test class defined in alu_test.sv
    run_test("alu_test");
  end

  // 4. Waveform Dumping
  initial begin
    $dumpfile("alu_dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
