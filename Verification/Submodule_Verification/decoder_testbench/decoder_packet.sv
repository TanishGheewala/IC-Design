/*
* decoder_packet contains the data structure used in testing the decoder.
*
*/
`include "../submodule_packet.sv"

class decoder_packet extends submodule_packet;

    //input
    rand bit [31:0] instruction;

    //outputs
    bit [4:0] rs1_addr;
    bit [4:0] rs2_addr;
    bit [4:0] rd_addr;
    bit [5:0] alu_opcode;
    bit       alu_src;
    bit       alu_a_src;
    bit [2:0] imm_type;
    bit       mem_read;
    bit       mem_write;
    bit       reg_write;
    bit [1:0] wb_sel;
    bit       branch_flag;
    bit       jump_flag;
    bit [2:0] branch_opcode;
    bit       illegal_instr;

    //restrict opcode field (instruction[6:0]) to the 9 legal RV32I opcode groups
    constraint valid_opcode {
        instruction[6:0] inside {
            7'b0110011, // R-type
            7'b0010011, // I-type ALU
            7'b0000011, // LOAD
            7'b0100011, // STORE
            7'b1100011, // BRANCH
            7'b1101111, // JAL
            7'b1100111, // JALR
            7'b0110111, // LUI
            7'b0010111  // AUIPC
        };
    }

    //funct7 only has two legal values in RV32I (all-zero, or bit 30 set for
    //SUB/SRA/SRAI), and only matters for R-type and the two I-type shift ops
    constraint valid_funct7 {
        (instruction[6:0] == 7'b0110011) ->
            instruction[31:25] inside {7'b0000000, 7'b0100000};

        (instruction[6:0] == 7'b0010011 && instruction[14:12] inside {3'b001, 3'b101}) ->
            instruction[31:25] inside {7'b0000000, 7'b0100000};
    }

    //function override for decoder
    virtual function string convert_to_string();
        return $sformatf("[DECODER TESTBENCH OUTPUT] instruction: 0x%08h | rs1: %0d rs2: %0d rd: %0d | alu_opcode: %06b alu_src: %0b alu_a_src: %0b | imm_type: %03b | mem_read: %0b mem_write: %0b | reg_write: %0b wb_sel: %02b | branch_flag: %0b jump_flag: %0b branch_opcode: %03b | illegal: %0b",
                            instruction, rs1_addr, rs2_addr, rd_addr,
                            alu_opcode, alu_src, alu_a_src, imm_type,
                            mem_read, mem_write, reg_write, wb_sel,
                            branch_flag, jump_flag, branch_opcode, illegal_instr);
    endfunction

endclass