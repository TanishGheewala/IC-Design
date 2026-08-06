/*
*   Sign Extender: sign extends data if needed
*/

`timescale 1ns/1ps

`define LUI     7'b0110111 // Load Upper Immediate 
`define AUIPC   7'b0010111 // Add Upper Immediate to PC 
`define JAL     7'b1101111 // Jump and Link
`define BRANCH  7'b1100011 // Branch Instructions 
`define STORE   7'b0100011 // Store Instructions 
`define ALU     7'b0110011 // ALU Instructions 
`define JALR    7'b1100111 // Jump and Link Register 
`define LOAD    7'b0000011 // Load Instructions 
`define ALUI    7'b0010011 // ALU Immediate Instructions 

module sign_extender(sign_extender_interface.se_dut se_if);

always_comb begin
    unique case(se_if.sign_extender_opcode)
        `LUI, 
        `AUIPC: se_if.immediate_output = {se_if.instruction_input[31:12], {12{1'b0}}};
        `JAL: se_if.immediate_output = {{12{se_if.instruction_input[31]}}, se_if.instruction_input[19:12], 
                                        se_if.instruction_input[20], se_if.instruction_input[30:21], 1'b0};
        `BRANCH: se_if.immediate_output = {{20{se_if.instruction_input[31]}}, se_if.instruction_input[7], 
                                        se_if.instruction_input[30:25], se_if.instruction_input[11:8], 1'b0};
        `STORE: se_if.immediate_output = {{21{se_if.instruction_input[31]}}, se_if.instruction_input[30:25], 
                                        se_if.instruction_input[11:7]};
        `ALU: se_if.immediate_output = {32{1'b0}};
        `JALR,
        `LOAD,
        `ALUI: se_if.immediate_output = {{21{se_if.instruction_input[31]}}, se_if.instruction_input[30:20]};
        default: se_if.immediate_output ={32{1'b0}};
    endcase
end
endmodule