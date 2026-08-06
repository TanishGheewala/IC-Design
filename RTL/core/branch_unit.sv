/*
*   Branch Unit: Sets flag to tell cpu to branch to new instruction memory location.
*/

`timescale 1ns/1ps

`define BEQ      3'b000 // Branch Equal
`define BNE      3'b001 // Branch Not Equal
`define BLT      3'b100 // Branch Less Than
`define BGE      3'b101 // Branch Greater Than Or Equal
`define BLTU     3'b110 // Branch Less Than Unsigned
`define BGEU     3'b111 // Branch Greater Than Or Equal Unsigned
`define JIC      3'b010 // Jump in case of JAL or JALR instrucion

module branch_unit(branch_unit_interface.bu_dut bu_if);
    logic branch_logic_out;
    always_comb begin
        //branch logic
        unique case(bu_if.branch_opcode)
            `BEQ: branch_logic_out = (bu_if.input_0 == bu_if.input_1);
            `BNE: branch_logic_out = (bu_if.input_0 != bu_if.input_1);
            `BLT: branch_logic_out = ($signed(bu_if.input_0) < $signed(bu_if.input_1));
            `BGE: branch_logic_out = ($signed(bu_if.input_0) >= $signed(bu_if.input_1));
            `BLTU: branch_logic_out = ($unsigned(bu_if.input_0) < $unsigned(bu_if.input_1));
            `BGEU: branch_logic_out = ($unsigned(bu_if.input_0) >= $unsigned(bu_if.input_1));
            `JIC: branch_logic_out = 1'b1;
        endcase

        //check if branch instruction
        unique case(bu_if.branch_flag)
            1'b1: bu_if.output_flag = branch_logic_out;
            1'b0: bu_if.output_flag = 0;
        endcase
    end

endmodule