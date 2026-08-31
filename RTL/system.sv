// system.v - Top Level Module for the Single-Cycle RV32I Datapath

`timescale 1ns/1ps
`include "memory/macros.vh"

module system (
    input logic clk,
    input logic rst_n
  );

  // Program Counter
  logic [`ADDR_WIDTH-1:0] pc = 0;
  logic [`ADDR_WIDTH-1:0] pc_next = 4;
  logic [`ADDR_WIDTH-1:0] pc_plus4;
  logic [`ADDR_WIDTH-1:0] pc_plus_imm;

  always_ff @(posedge clk)
  begin
    if (!rst_n)
      pc <= '0;
    else
      pc <= pc_next;

    $strobe("[STROBE DEBUG] Time: %0t | pc: %h | pc_next: %h", $time, pc, pc_next);
    $strobe("[STROBE DEBUG] Time: %0t | rom_if.inst: %h", $time, rom_if.inst);
  end

  // Interfaces
  instruction_memory_interface  rom_if();
  data_memory_interface         ram_if();
  decoder_interface             dec_if();
  register_file_interface       rf_if();
  sign_extender_interface       se_if();
  alu_interface                 alu_if();
  branch_unit_interface         bu_if();

  // Fetch
  assign rom_if.addr = pc;

  instruction_memory #(
                       .MEM_INITIAL_FILE("test_program.hex"))
                      rom (.addr(rom_if.addr),
                       .inst(rom_if.inst)
                      );

  // Decode
  assign dec_if.instruction = rom_if.inst;

  decoder u_decoder (.dec_if(dec_if));

  assign se_if.sign_extender_opcode = rom_if.inst[6:0];
  assign se_if.instruction_input    = rom_if.inst;

  sign_extender u_sign_extender (.se_if(se_if));

  assign rf_if.clk       = clk;
  assign rf_if.rs1_addr  = dec_if.rs1_addr;
  assign rf_if.rs2_addr  = dec_if.rs2_addr;
  assign rf_if.rd_addr   = dec_if.rd_addr;
  assign rf_if.reg_write = dec_if.reg_write;

  register_file u_register_file (.rf_if(rf_if));

  // Execute
  assign alu_if.alu_opcode = dec_if.alu_opcode;
  assign alu_if.in_data_0  = dec_if.alu_a_src
         ? {{(32-`ADDR_WIDTH){1'b0}}, pc}
         : rf_if.rs1_data;
  assign alu_if.in_data_1  = dec_if.alu_src
         ? se_if.immediate_output
         : rf_if.rs2_data;

  alu u_alu (.alu_if(alu_if));

  assign bu_if.branch_flag   = dec_if.branch_flag;
  assign bu_if.branch_opcode = dec_if.branch_opcode;
  assign bu_if.input_0       = rf_if.rs1_data;
  assign bu_if.input_1       = rf_if.rs2_data;

  branch_unit u_branch_unit (.bu_if(bu_if));

  // Memory
  assign ram_if.we      = dec_if.mem_write;
  assign ram_if.addr    = alu_if.out_data[`ADDR_WIDTH-1:0];
  assign ram_if.data_in = rf_if.rs2_data;

  data_memory ram (
                .clk     (clk),
                .we      (ram_if.we),
                .addr    (ram_if.addr),
                .data_in (ram_if.data_in),
                .data_out(ram_if.data_out)
              );


  // Writeback
  assign pc_plus4    = pc + `ADDR_WIDTH'd4;
  assign pc_plus_imm = pc + se_if.immediate_output[`ADDR_WIDTH-1:0];

  logic take_branch;
  assign take_branch = dec_if.branch_flag && bu_if.output_flag;

  always_comb
  begin
    if (take_branch)
    begin
      if (dec_if.jump_flag && dec_if.alu_src)
        pc_next = alu_if.out_data[`ADDR_WIDTH-1:0]; // JALR
      else
        pc_next = pc_plus_imm;
    end
    else
      pc_next = pc_plus4;
  end

  always_comb
  begin
    case (dec_if.wb_sel)
      2'b00:
        rf_if.write_data = alu_if.out_data;
      2'b01:
        rf_if.write_data = ram_if.data_out;
      2'b10:
        rf_if.write_data = {{(32-`ADDR_WIDTH){1'b0}}, pc_plus4};
      default:
        rf_if.write_data = alu_if.out_data;
    endcase
  end

endmodule
