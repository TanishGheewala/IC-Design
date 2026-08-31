/*
* RISC V core top module
*/
`timescale 1ns/1ps
`include "memory/macros.vh"

module core(core_interface.dut core_if);
    
// Program Counter
    logic [`ADDR_WIDTH-1:0] pc = 0;
    logic [`ADDR_WIDTH-1:0] pc_next = 0;
    logic [`ADDR_WIDTH-1:0] pc_plus4;
    logic [`ADDR_WIDTH-1:0] pc_plus_imm;


endmodule
