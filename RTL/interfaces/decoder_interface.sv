/*
* Interface for decoder module. Defines all I/O ports.
*   000 = I-type   001 = S-type   010 = B-type   011 = U-type   100 = J-type
*
* wb_sel selects what the register file write-back mux should choose:
*   00 = ALU result   01 = data memory read data   10 = PC + 4 (link address)
*
* alu_opcode uses the same 6-bit encoding as alu_interface.alu_opcode.
* branch_opcode uses the same 3-bit encoding (funct3) as branch_unit_interface.branch_opcode,
* with 3'b010 (JIC) reserved for unconditional jumps (JAL/JALR).
*/

`timescale 1ns/1ps

interface decoder_interface();

    //32-bit instruction
    logic [31:0] instruction;

    //register addresses
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;

    //execution control
    logic [5:0] alu_opcode;
    logic       alu_src;    //0 = ALU operand B is rs2 data, 1 = ALU operand B is immediate
    logic       alu_a_src;  //0 = ALU operand A is rs1 data, 1 = ALU operand A is PC (AUIPC)

    //immediate control
    logic [2:0] imm_type;

    //memory control
    logic mem_read;
    logic mem_write;

    //writeback control
    logic       reg_write;
    logic [1:0] wb_sel;

    //branch/jump control
    logic       branch_flag;    //high for branches AND jumps, feeds branch_unit enable
    logic       jump_flag;      //high only for JAL/JALR, distinguishes from conditional branch
    logic [2:0] branch_opcode;  //funct3 passthrough, JIC for jumps

    //decode error
    logic illegal_instr;

    //dut setup
    modport dec_dut
    (
        input  instruction,
        output rs1_addr,
        output rs2_addr,
        output rd_addr,
        output alu_opcode,
        output alu_src,
        output alu_a_src,
        output imm_type,
        output mem_read,
        output mem_write,
        output reg_write,
        output wb_sel,
        output branch_flag,
        output jump_flag,
        output branch_opcode,
        output illegal_instr
    );

endinterface