package alu_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

/*
`include "alu_driver.sv"
`include "alu_monitor.sv"
`include "alu_sequence_item.sv"
`include "alu_sequence.sv"
`include "alu_scoreboard.sv"
`include "alu_agent.sv"
`include "alu_environment.sv"
`include "alu_test.sv"
`include "top.sv"
*/

// ALU Opcode:

/* ALU OPCODE
  typedef enum logic [5:0] {
    ALU_ADD   = 6'b011001,
    ALU_SUB   = 6'b011010,
    ALU_AND   = 6'b011011,
    ALU_OR    = 6'b011100,
    ALU_XOR   = 6'b011101,
    ALU_SLL   = 6'b011110,
    ALU_SRL   = 6'b011111,
    ALU_SRA   = 6'b100000,
    ALU_SLT   = 6'b100001,
    ALU_SLTU  = 6'b100010,
    ALU_PASSA = 6'b100011,
    ALU_PASSB = 6'b100100
  } alu_opcode_t;
  */

  // Unique Case ?

  // Other Logic? Signed/Unsigned, Overflow, etc.?


    endcase
endpackage