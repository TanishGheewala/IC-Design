// ALU Wrapper (for Genus synthesis)

module alu_synth_top (
    input  logic [5:0]  alu_opcode,
    input  logic [31:0] in_data_0,
    input  logic [31:0] in_data_1,
    output logic [31:0] out_data
  );
  alu_interface alu_if();
  assign alu_if.alu_opcode = alu_opcode;
  assign alu_if.in_data_0  = in_data_0;
  assign alu_if.in_data_1  = in_data_1;
  assign out_data          = alu_if.out_data;
  alu u_alu (.alu_if(alu_if));
endmodule
