// decoder.sv

`timescale 1ns/1ps

module decoder(decoder_interface.dec_dut dec_if);

    //instruction field extraction
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = dec_if.instruction[6:0];
        funct3 = dec_if.instruction[14:12];
        funct7 = dec_if.instruction[31:25];

        //register addresses are in the same position for every format that uses them
        //(U-type and J-type only have rd)
        dec_if.rs1_addr = dec_if.instruction[19:15];
        dec_if.rs2_addr = dec_if.instruction[24:20];
        dec_if.rd_addr  = dec_if.instruction[11:7];
    end

    //opcode map (RV32I base ISA)
    localparam logic [6:0] OP_R      = 7'b0110011; // R-type ALU
    localparam logic [6:0] OP_I      = 7'b0010011; // I-type ALU
    localparam logic [6:0] OP_LOAD   = 7'b0000011; // LB/LH/LW/LBU/LHU
    localparam logic [6:0] OP_STORE  = 7'b0100011; // SB/SH/SW
    localparam logic [6:0] OP_BRANCH = 7'b1100011; // BEQ/BNE/BLT/BGE/BLTU/BGEU
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;
    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;

    //immediate type selectors, sent to the sign extender
    localparam logic [2:0] IMM_I = 3'b000;
    localparam logic [2:0] IMM_S = 3'b001;
    localparam logic [2:0] IMM_B = 3'b010;
    localparam logic [2:0] IMM_U = 3'b011;
    localparam logic [2:0] IMM_J = 3'b100;

    //writeback source selectors
    localparam logic [1:0] WB_ALU = 2'b00;
    localparam logic [1:0] WB_MEM = 2'b01;
    localparam logic [1:0] WB_PC4 = 2'b10;

    //ALU opcodes
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
    localparam logic [5:0] ALU_PASSA = 6'b100011;
    localparam logic [5:0] ALU_PASSB = 6'b100100;

    //branch opcodes
    localparam logic [2:0] BR_BEQ  = 3'b000;
    localparam logic [2:0] BR_BNE  = 3'b001;
    localparam logic [2:0] BR_BLT  = 3'b100;
    localparam logic [2:0] BR_BGE  = 3'b101;
    localparam logic [2:0] BR_BLTU = 3'b110;
    localparam logic [2:0] BR_BGEU = 3'b111;
    localparam logic [2:0] BR_JIC  = 3'b010; // unconditional jump indicator

    //R-type / I-type ALU op selection, shared since most I-type ALU ops mirror R-type
    logic [5:0] alu_op_rtype;
    logic [5:0] alu_op_itype;

    always_comb begin
        unique case(funct3)
            3'b000:  alu_op_rtype = funct7[5] ? ALU_SUB : ALU_ADD;
            3'b001:  alu_op_rtype = ALU_SLL;
            3'b010:  alu_op_rtype = ALU_SLT;
            3'b011:  alu_op_rtype = ALU_SLTU;
            3'b100:  alu_op_rtype = ALU_XOR;
            3'b101:  alu_op_rtype = funct7[5] ? ALU_SRA : ALU_SRL;
            3'b110:  alu_op_rtype = ALU_OR;
            3'b111:  alu_op_rtype = ALU_AND;
            default: alu_op_rtype = ALU_ADD;
        endcase

        unique case(funct3)
            3'b000:  alu_op_itype = ALU_ADD;  // addi
            3'b001:  alu_op_itype = ALU_SLL;  // slli (shamt = imm[4:0])
            3'b010:  alu_op_itype = ALU_SLT;  // slti
            3'b011:  alu_op_itype = ALU_SLTU; // sltiu
            3'b100:  alu_op_itype = ALU_XOR;  // xori
            3'b101:  alu_op_itype = funct7[5] ? ALU_SRA : ALU_SRL; // srai/srli
            3'b110:  alu_op_itype = ALU_OR;   // ori
            3'b111:  alu_op_itype = ALU_AND;  // andi
        endcase
    end

    //main control decode
    always_comb begin
        //safe defaults, override per-opcode below
        dec_if.alu_opcode    = ALU_ADD;
        dec_if.alu_src       = 1'b0;
        dec_if.alu_a_src     = 1'b0;
        dec_if.imm_type      = IMM_I;
        dec_if.mem_read      = 1'b0;
        dec_if.mem_write     = 1'b0;
        dec_if.reg_write     = 1'b0;
        dec_if.wb_sel        = WB_ALU;
        dec_if.branch_flag   = 1'b0;
        dec_if.jump_flag     = 1'b0;
        dec_if.branch_opcode = BR_BEQ;
        dec_if.illegal_instr = 1'b0;

        case(opcode)

            OP_R: begin
                dec_if.reg_write  = 1'b1;
                dec_if.alu_src    = 1'b0;
                dec_if.wb_sel     = WB_ALU;
                dec_if.alu_opcode = alu_op_rtype;
            end

            OP_I: begin
                dec_if.reg_write  = 1'b1;
                dec_if.alu_src    = 1'b1;
                dec_if.wb_sel     = WB_ALU;
                dec_if.imm_type   = IMM_I;
                dec_if.alu_opcode = alu_op_itype;
            end

            OP_LOAD: begin
                dec_if.reg_write  = 1'b1;
                dec_if.alu_src    = 1'b1;
                dec_if.mem_read   = 1'b1;
                dec_if.wb_sel     = WB_MEM;
                dec_if.imm_type   = IMM_I;
                dec_if.alu_opcode = ALU_ADD; // address = rs1 + imm
            end

            OP_STORE: begin
                dec_if.alu_src    = 1'b1;
                dec_if.mem_write  = 1'b1;
                dec_if.imm_type   = IMM_S;
                dec_if.alu_opcode = ALU_ADD; // address = rs1 + imm
            end

            OP_BRANCH: begin
                dec_if.alu_src       = 1'b0;
                dec_if.imm_type      = IMM_B;
                dec_if.branch_flag   = 1'b1;
                dec_if.jump_flag     = 1'b0;
                dec_if.branch_opcode = funct3;
            end

            OP_JAL: begin
                dec_if.reg_write     = 1'b1;
                dec_if.wb_sel        = WB_PC4;
                dec_if.imm_type      = IMM_J;
                dec_if.branch_flag   = 1'b1;
                dec_if.jump_flag     = 1'b1;
                dec_if.branch_opcode = BR_JIC;
            end

            OP_JALR: begin
                dec_if.reg_write     = 1'b1;
                dec_if.alu_src       = 1'b1;
                dec_if.wb_sel        = WB_PC4;
                dec_if.imm_type      = IMM_I;
                dec_if.alu_opcode    = ALU_ADD; // target = rs1 + imm
                dec_if.branch_flag   = 1'b1;
                dec_if.jump_flag     = 1'b1;
                dec_if.branch_opcode = BR_JIC;
            end

            OP_LUI: begin
                dec_if.reg_write  = 1'b1;
                dec_if.alu_src    = 1'b1;
                dec_if.wb_sel     = WB_ALU;
                dec_if.imm_type   = IMM_U;
                dec_if.alu_opcode = ALU_PASSB; // rd = imm
            end

            OP_AUIPC: begin
                dec_if.reg_write  = 1'b1;
                dec_if.alu_src    = 1'b1;
                dec_if.alu_a_src  = 1'b1; // operand A = PC
                dec_if.wb_sel     = WB_ALU;
                dec_if.imm_type   = IMM_U;
                dec_if.alu_opcode = ALU_ADD; // rd = PC + imm
            end

            default: begin
                dec_if.illegal_instr = 1'b1;
            end

        endcase
    end

endmodule