/*
* RISC-V core top module
*/

`timescale 1ns/1ps
`include "../memory/macros.vh"

module core #(
    parameter ADDR_WIDTH = `ADDR_WIDTH,
    parameter MEM_DEPTH = `MEM_DEPTH,
    parameter ROM_INITIAL_FILE = "test_program.hex",
    parameter RAM_INITIAL_FILE = "",
    parameter DEBUG_PRINT = 1'b1
)
(
    core_interface core_if
);

    // Internal interfaces
    decoder_interface       dec_if();
    register_file_interface rf_if();
    sign_extender_interface se_if();
    alu_interface           alu_if();
    branch_unit_interface   bu_if();

    // Program counter
    logic [ADDR_WIDTH-1:0] pc = '0;
    logic [ADDR_WIDTH-1:0] pc_next = '0;
    logic [ADDR_WIDTH-1:0] pc_plus4;
    logic [ADDR_WIDTH-1:0] pc_plus_imm;

    // Wait cycle for synchronous SRAM reads
    logic [1:0] clk_delay = '0;

    // Load formatting
    logic [7:0]  selected_byte;
    logic [15:0] selected_halfword;
    logic [31:0] load_data;

    // Store formatting
    logic [31:0] store_data;
    logic [3:0]  store_mask;

    // Core submodules
    decoder u_decoder (
        .dec_if(dec_if)
    );

    sign_extender u_sign_extender (
        .se_if(se_if)
    );

    register_file u_register_file (
        .rf_if(rf_if)
    );

    alu u_alu (
        .alu_if(alu_if)
    );

    branch_unit u_branch_unit (
        .bu_if(bu_if)
    );

    // Program-counter register and SRAM wait cycle
    always_ff @(posedge core_if.clk)
    begin
        if (!core_if.rst_n)
        begin
            pc        <= '0;
            clk_delay <= '0;
        end
        else if (core_if.core_halt)
        begin
            pc        <= pc;
            clk_delay <= '0;
        end
        else if (clk_delay == 2'd1)
        begin
            pc        <= pc_next;
            clk_delay <= '0;
        end
        else
        begin
            clk_delay <= clk_delay + 1'b1;
        end

        if (DEBUG_PRINT)
        begin
            $strobe(
                "[STROBE DEBUG] Time: %0t | pc: %h | pc_next: %h",
                $time,
                pc,
                pc_next
            );

            $strobe(
                "[STROBE DEBUG] Time: %0t | instruction: %h",
                $time,
                core_if.rom_read
            );
        end
    end

    // Next-PC logic
    always_comb
    begin
        pc_plus4    = pc + 4;
        pc_plus_imm = pc + se_if.immediate_output[ADDR_WIDTH-1:0];

        if (core_if.core_halt)
        begin
            pc_next = pc;
        end
        else if (bu_if.output_flag)
        begin
            // JALR uses rs1 + immediate and must clear target bit zero.
            if (dec_if.jump_flag && dec_if.alu_src)
                pc_next = {alu_if.out_data[ADDR_WIDTH-1:1], 1'b0};
            else
                // Conditional branches and JAL use PC + immediate.
                pc_next = pc_plus_imm;
        end
        else
        begin
            pc_next = pc_plus4;
        end
    end

    // Instruction-memory connection
    always_comb
    begin
        core_if.rom_address = pc;
    end

    // Decoder and sign-extender connections
    always_comb
    begin
        dec_if.instruction = core_if.rom_read;

        se_if.sign_extender_opcode = core_if.rom_read[6:0];
        se_if.instruction_input    = core_if.rom_read;
    end

    // ALU connections
    always_comb
    begin
        alu_if.alu_opcode = dec_if.alu_opcode;

        if (dec_if.alu_a_src)
            alu_if.in_data_0 = {{(32-ADDR_WIDTH){1'b0}}, pc};
        else
            alu_if.in_data_0 = rf_if.rs1_data;

        if (dec_if.alu_src)
            alu_if.in_data_1 = se_if.immediate_output;
        else
            alu_if.in_data_1 = rf_if.rs2_data;
    end

    // Branch-unit connections
    always_comb
    begin
        bu_if.branch_flag   = dec_if.branch_flag;
        bu_if.branch_opcode = dec_if.branch_opcode;
        bu_if.input_0       = rf_if.rs1_data;
        bu_if.input_1       = rf_if.rs2_data;
    end

    // Register-file connections
    always_comb
    begin
        rf_if.clk       = core_if.clk;
        rf_if.rs1_addr  = dec_if.rs1_addr;
        rf_if.rs2_addr  = dec_if.rs2_addr;
        rf_if.rd_addr   = dec_if.rd_addr;

        // Commit only after the SRAM wait cycle has completed.
        rf_if.reg_write = dec_if.reg_write &&
                          (clk_delay == 2'd1);

        if (core_if.core_halt)
        begin
            rf_if.reg_write = 1'b0;

            if (core_if.debug_controller_instruction == 8'h01)
                rf_if.rs1_addr = core_if.debug_address[4:0];
        end
    end

    // Select the addressed byte and halfword from the SRAM word.
    always_comb
    begin
        case (alu_if.out_data[1:0])
            2'b00:
                selected_byte = core_if.memory_read[7:0];

            2'b01:
                selected_byte = core_if.memory_read[15:8];

            2'b10:
                selected_byte = core_if.memory_read[23:16];

            default:
                selected_byte = core_if.memory_read[31:24];
        endcase

        if (alu_if.out_data[1])
            selected_halfword = core_if.memory_read[31:16];
        else
            selected_halfword = core_if.memory_read[15:0];

        case (core_if.rom_read[14:12])
            3'b000:
                load_data = {
                    {24{selected_byte[7]}},
                    selected_byte
                }; // LB

            3'b001:
                load_data = {
                    {16{selected_halfword[15]}},
                    selected_halfword
                }; // LH

            3'b010:
                load_data = core_if.memory_read; // LW

            3'b100:
                load_data = {
                    24'b0,
                    selected_byte
                }; // LBU

            3'b101:
                load_data = {
                    16'b0,
                    selected_halfword
                }; // LHU

            default:
                load_data = core_if.memory_read;
        endcase
    end

    // Register-file writeback selection
    always_comb
    begin
        case (dec_if.wb_sel)
            2'b00:
                rf_if.write_data = alu_if.out_data;

            2'b01:
                rf_if.write_data = load_data;

            2'b10:
                rf_if.write_data =
                    {{(32-ADDR_WIDTH){1'b0}}, pc_plus4};

            default:
                rf_if.write_data = alu_if.out_data;
        endcase
    end

    // Format store data and generate SRAM byte-write masks.
    always_comb
    begin
        store_data = rf_if.rs2_data;
        store_mask = 4'b0000;

        case (core_if.rom_read[14:12])
            3'b000:
            begin
                // SB: repeat the source byte across every lane, then
                // enable only the addressed byte.
                store_data = {4{rf_if.rs2_data[7:0]}};

                case (alu_if.out_data[1:0])
                    2'b00:
                        store_mask = 4'b0001;

                    2'b01:
                        store_mask = 4'b0010;

                    2'b10:
                        store_mask = 4'b0100;

                    default:
                        store_mask = 4'b1000;
                endcase
            end

            3'b001:
            begin
                // SH: repeat the halfword and enable the addressed pair.
                store_data = {2{rf_if.rs2_data[15:0]}};

                if (alu_if.out_data[1])
                    store_mask = 4'b1100;
                else
                    store_mask = 4'b0011;
            end

            3'b010:
            begin
                // SW
                store_data = rf_if.rs2_data;
                store_mask = 4'b1111;
            end

            default:
            begin
                store_data = rf_if.rs2_data;
                store_mask = 4'b0000;
            end
        endcase
    end

    // External data-memory connections
    always_comb
    begin
        core_if.memory_write_en   = 1'b0;
        core_if.memory_write_mask = store_mask;
        core_if.memory_address =
            alu_if.out_data;
        core_if.memory_write      = store_data;

        if (core_if.core_halt)
        begin
            core_if.memory_write_mask = 4'b0000;

            if (core_if.debug_controller_instruction == 8'h02)
                core_if.memory_address =
                    core_if.debug_address;
        end
        else
        begin
            // Write only on the final execution cycle.
            core_if.memory_write_en =
                dec_if.mem_write && (clk_delay == 2'd1);
        end
    end

    // Debug readback
    always_comb
    begin
        if (core_if.core_halt)
        begin
            unique case (core_if.debug_controller_instruction)
                8'h01:
                    core_if.debug_data_return = rf_if.rs1_data;

                8'h02:
                    core_if.debug_data_return =
                        core_if.memory_read;

                default:
                    core_if.debug_data_return = '0;
            endcase
        end
        else
        begin
            core_if.debug_data_return = '0;
        end
    end

endmodule
