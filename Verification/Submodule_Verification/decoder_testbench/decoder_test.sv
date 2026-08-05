/*
* decoder_test is the top level testbench for the decoder
*/
`include "decoder_packet.sv"
`timescale 1ns/1ps
module decoder_tb;

    //interface
    decoder_interface decoder_if();

    //DUT
    decoder DUT (
        .dec_if(decoder_if.dec_dut)
    );

    //error counting variable
    int error_counter = 0;

    //opcode map, mirrors decoder.sv
    localparam logic [6:0] OP_R      = 7'b0110011;
    localparam logic [6:0] OP_I      = 7'b0010011;
    localparam logic [6:0] OP_LOAD   = 7'b0000011;
    localparam logic [6:0] OP_STORE  = 7'b0100011;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;
    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;

    localparam logic [2:0] IMM_I = 3'b000;
    localparam logic [2:0] IMM_S = 3'b001;
    localparam logic [2:0] IMM_B = 3'b010;
    localparam logic [2:0] IMM_U = 3'b011;
    localparam logic [2:0] IMM_J = 3'b100;

    localparam logic [1:0] WB_ALU = 2'b00;
    localparam logic [1:0] WB_MEM = 2'b01;
    localparam logic [1:0] WB_PC4 = 2'b10;

    localparam logic [5:0] ALU_ADD   = 6'b011001;
    localparam logic [5:0] ALU_SUB   = 6'b011010;
    localparam logic [5:0] ALU_AND   = 6'b011011;
    localparam logic [5:0] ALU_OR    = 6'b011100;
    localparam logic [5:0] ALU_XOR   = 6'b011101;
    localparam logic [5:0] ALU_SLL   = 6'b011110;
    localparam logic [5:0] ALU_SRL   = 6'b011111;
    localparam logic [5:0] ALU_SRA   = 6'b100000;
    localparam logic [5:0] ALU_SLT   = 6'b100001;
    localparam logic [5:0] ALU_SLTU  = 6'b100010;
    localparam logic [5:0] ALU_PASSB = 6'b100100;

    localparam logic [2:0] BR_BEQ = 3'b000;
    localparam logic [2:0] BR_JIC = 3'b010;

    //acts as scoreboard, checks results against expected output
    function bit expected_result(decoder_packet data);
        bit error;
        //extracts instruction fields and calculates expected outputs based on the instruction
        logic [6:0] opcode;
        logic [2:0] funct3;
        logic [6:0] funct7;
        //expected outputs
        logic [4:0] exp_rs1_addr;
        logic [4:0] exp_rs2_addr;
        logic [4:0] exp_rd_addr;
        logic [5:0] exp_alu_opcode;
        logic       exp_alu_src;
        logic       exp_alu_a_src;
        logic [2:0] exp_imm_type;
        logic       exp_mem_read;
        logic       exp_mem_write;
        logic       exp_reg_write;
        logic [1:0] exp_wb_sel;
        logic       exp_branch_flag;
        logic       exp_jump_flag;
        logic [2:0] exp_branch_opcode;
        logic       exp_illegal_instr;

        //EXTRACT INSTRUCTION FIELDS
        opcode = data.instruction[6:0];
        funct3 = data.instruction[14:12];
        funct7 = data.instruction[31:25];

        exp_rs1_addr = data.instruction[19:15];
        exp_rs2_addr = data.instruction[24:20];
        exp_rd_addr  = data.instruction[11:7];

        //defaults, overridden per-opcode below
        exp_alu_opcode    = ALU_ADD;
        exp_alu_src       = 1'b0;
        exp_alu_a_src     = 1'b0;
        exp_imm_type      = IMM_I;
        exp_mem_read      = 1'b0;
        exp_mem_write     = 1'b0;
        exp_reg_write     = 1'b0;
        exp_wb_sel        = WB_ALU;
        exp_branch_flag   = 1'b0;
        exp_jump_flag     = 1'b0;
        exp_branch_opcode = BR_BEQ;
        exp_illegal_instr = 1'b0;

        case(opcode)

            OP_R: begin
                exp_reg_write = 1'b1;
                exp_alu_src   = 1'b0;
                exp_wb_sel    = WB_ALU;
                case(funct3)
                    3'b000:  exp_alu_opcode = funct7[5] ? ALU_SUB : ALU_ADD;
                    3'b001:  exp_alu_opcode = ALU_SLL;
                    3'b010:  exp_alu_opcode = ALU_SLT;
                    3'b011:  exp_alu_opcode = ALU_SLTU;
                    3'b100:  exp_alu_opcode = ALU_XOR;
                    3'b101:  exp_alu_opcode = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110:  exp_alu_opcode = ALU_OR;
                    3'b111:  exp_alu_opcode = ALU_AND;
                    default: exp_alu_opcode = ALU_ADD;
                endcase
            end

            OP_I: begin
                exp_reg_write = 1'b1;
                exp_alu_src   = 1'b1;
                exp_wb_sel    = WB_ALU;
                exp_imm_type  = IMM_I;
                case(funct3)
                    3'b000:  exp_alu_opcode = ALU_ADD;
                    3'b001:  exp_alu_opcode = ALU_SLL;
                    3'b010:  exp_alu_opcode = ALU_SLT;
                    3'b011:  exp_alu_opcode = ALU_SLTU;
                    3'b100:  exp_alu_opcode = ALU_XOR;
                    3'b101:  exp_alu_opcode = funct7[5] ? ALU_SRA : ALU_SRL;
                    3'b110:  exp_alu_opcode = ALU_OR;
                    3'b111:  exp_alu_opcode = ALU_AND;
                    default: exp_alu_opcode = ALU_ADD;
                endcase
            end

            OP_LOAD: begin
                exp_reg_write  = 1'b1;
                exp_alu_src    = 1'b1;
                exp_mem_read   = 1'b1;
                exp_wb_sel     = WB_MEM;
                exp_imm_type   = IMM_I;
                exp_alu_opcode = ALU_ADD;
            end

            OP_STORE: begin
                exp_alu_src    = 1'b1;
                exp_mem_write  = 1'b1;
                exp_imm_type   = IMM_S;
                exp_alu_opcode = ALU_ADD;
            end

            OP_BRANCH: begin
                exp_alu_src       = 1'b0;
                exp_imm_type      = IMM_B;
                exp_branch_flag   = 1'b1;
                exp_jump_flag     = 1'b0;
                exp_branch_opcode = funct3;
            end

            OP_JAL: begin
                exp_reg_write     = 1'b1;
                exp_wb_sel        = WB_PC4;
                exp_imm_type      = IMM_J;
                exp_branch_flag   = 1'b1;
                exp_jump_flag     = 1'b1;
                exp_branch_opcode = BR_JIC;
            end

            OP_JALR: begin
                exp_reg_write     = 1'b1;
                exp_alu_src       = 1'b1;
                exp_wb_sel        = WB_PC4;
                exp_imm_type      = IMM_I;
                exp_alu_opcode    = ALU_ADD;
                exp_branch_flag   = 1'b1;
                exp_jump_flag     = 1'b1;
                exp_branch_opcode = BR_JIC;
            end

            OP_LUI: begin
                exp_reg_write  = 1'b1;
                exp_alu_src    = 1'b1;
                exp_wb_sel     = WB_ALU;
                exp_imm_type   = IMM_U;
                exp_alu_opcode = ALU_PASSB;
            end

            OP_AUIPC: begin
                exp_reg_write  = 1'b1;
                exp_alu_src    = 1'b1;
                exp_alu_a_src  = 1'b1;
                exp_wb_sel     = WB_ALU;
                exp_imm_type   = IMM_U;
                exp_alu_opcode = ALU_ADD;
            end

            default: begin
                exp_illegal_instr = 1'b1;
            end

        endcase

        //compares every decoder output against the reference model
        //prints exactly which field(s) mismatched
        error = 0;

        if (data.rs1_addr !== exp_rs1_addr) begin
            $error("rs1_addr mismatch: expected %0d, got %0d", exp_rs1_addr, data.rs1_addr);
            error = 1;
        end
        if (data.rs2_addr !== exp_rs2_addr) begin
            $error("rs2_addr mismatch: expected %0d, got %0d", exp_rs2_addr, data.rs2_addr);
            error = 1;
        end
        if (data.rd_addr !== exp_rd_addr) begin
            $error("rd_addr mismatch: expected %0d, got %0d", exp_rd_addr, data.rd_addr);
            error = 1;
        end
        if (data.alu_opcode !== exp_alu_opcode) begin
            $error("alu_opcode mismatch: expected %06b, got %06b", exp_alu_opcode, data.alu_opcode);
            error = 1;
        end
        if (data.alu_src !== exp_alu_src) begin
            $error("alu_src mismatch: expected %0b, got %0b", exp_alu_src, data.alu_src);
            error = 1;
        end
        if (data.alu_a_src !== exp_alu_a_src) begin
            $error("alu_a_src mismatch: expected %0b, got %0b", exp_alu_a_src, data.alu_a_src);
            error = 1;
        end
        if (data.imm_type !== exp_imm_type) begin
            $error("imm_type mismatch: expected %03b, got %03b", exp_imm_type, data.imm_type);
            error = 1;
        end
        if (data.mem_read !== exp_mem_read) begin
            $error("mem_read mismatch: expected %0b, got %0b", exp_mem_read, data.mem_read);
            error = 1;
        end
        if (data.mem_write !== exp_mem_write) begin
            $error("mem_write mismatch: expected %0b, got %0b", exp_mem_write, data.mem_write);
            error = 1;
        end
        if (data.reg_write !== exp_reg_write) begin
            $error("reg_write mismatch: expected %0b, got %0b", exp_reg_write, data.reg_write);
            error = 1;
        end
        if (data.wb_sel !== exp_wb_sel) begin
            $error("wb_sel mismatch: expected %02b, got %02b", exp_wb_sel, data.wb_sel);
            error = 1;
        end
        if (data.branch_flag !== exp_branch_flag) begin
            $error("branch_flag mismatch: expected %0b, got %0b", exp_branch_flag, data.branch_flag);
            error = 1;
        end
        if (data.jump_flag !== exp_jump_flag) begin
            $error("jump_flag mismatch: expected %0b, got %0b", exp_jump_flag, data.jump_flag);
            error = 1;
        end
        if (data.branch_opcode !== exp_branch_opcode) begin
            $error("branch_opcode mismatch: expected %03b, got %03b", exp_branch_opcode, data.branch_opcode);
            error = 1;
        end
        if (data.illegal_instr !== exp_illegal_instr) begin
            $error("illegal_instr mismatch: expected %0b, got %0b", exp_illegal_instr, data.illegal_instr);
            error = 1;
        end

        if (error) data.print();

        return error;
    endfunction

    //test begins
    initial begin
        decoder_packet decoder_item = new();

        $display("[DECODER TEST START]");

        //test 2000 random (constrained-legal) instructions
        repeat(2000) begin
            if (!decoder_item.randomize()) $fatal(1, "Randomization failed");

            decoder_if.instruction = decoder_item.instruction;

            #10;

            decoder_item.rs1_addr      = decoder_if.rs1_addr;
            decoder_item.rs2_addr      = decoder_if.rs2_addr;
            decoder_item.rd_addr       = decoder_if.rd_addr;
            decoder_item.alu_opcode    = decoder_if.alu_opcode;
            decoder_item.alu_src       = decoder_if.alu_src;
            decoder_item.alu_a_src     = decoder_if.alu_a_src;
            decoder_item.imm_type      = decoder_if.imm_type;
            decoder_item.mem_read      = decoder_if.mem_read;
            decoder_item.mem_write     = decoder_if.mem_write;
            decoder_item.reg_write     = decoder_if.reg_write;
            decoder_item.wb_sel        = decoder_if.wb_sel;
            decoder_item.branch_flag   = decoder_if.branch_flag;
            decoder_item.jump_flag     = decoder_if.jump_flag;
            decoder_item.branch_opcode = decoder_if.branch_opcode;
            decoder_item.illegal_instr = decoder_if.illegal_instr;

            //error counter
            error_counter = error_counter + expected_result(decoder_item);

        end

        //display results
        $display("[DECODER TEST COMPLETE]");
        $display("Total Errors: %0d", error_counter);
        $finish;
    end

endmodule