/*
* RISC V core top module
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
(core_interface core_if);
    
    //interfaces
    decoder_interface       dec_if();
    register_file_interface rf_if();
    sign_extender_interface se_if();
    alu_interface           alu_if();
    branch_unit_interface   bu_if();

    //pc register & multiplexor variables
    logic [ADDR_WIDTH-1:0] pc = '0;
    logic [ADDR_WIDTH-1:0] pc_next = '0;
    logic [ADDR_WIDTH-1:0] pc_plus4;

    //delay for sram reads for instuction memory and data memory
    //1 extra clk for each -- could replace with pipleline but requires extra logic for branch unit
    //would most likely do flush for everything if we did pipeline
    logic [1:0] clk_delay = '0;

    //core submodules
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

    //pc update
    always_ff @(posedge core_if.clk) begin
        if (!core_if.rst_n) begin
            pc <= '0;
        end
        else if(clk_delay == 1) begin
            pc <= pc_next;
            clk_delay <= 0;
        end
        else begin
            clk_delay <= clk_delay + 1;
        end

        if (DEBUG_PRINT) begin
            $strobe("[STROBE DEBUG] Time: %0t | pc: %h | pc_next: %h", $time, pc, pc_next);
            $strobe("[STROBE DEBUG] Time: %0t | rom_if.inst: %h", $time, core_if.rom_read);
        end
    end

    //pc updatae logic 
    always_comb begin
        pc_plus4 = pc + 4;
        if(core_if.core_halt) begin
            pc_next = pc;
        end
        else begin
            if (bu_if.output_flag) begin
                pc_next = alu_if.out_data;
            end
            else begin
                pc_next = pc_plus4;
            end
        end
    end

    //rom connections
    always_comb begin
        core_if.rom_address = pc;
    end

    //alu connections
    always_comb begin
        alu_if.alu_opcode = dec_if.alu_opcode;

        //multiplexors for input
        if(dec_if.alu_a_src) begin
            alu_if.in_data_0 = pc;
        end
        else begin
            alu_if.in_data_0 = rf_if.rs1_data;
        end

        if(dec_if.alu_src) begin
            alu_if.in_data_1 = se_if.immediate_output;
        end
        else begin
            alu_if.in_data_1 = rf_if.rs2_data;
        end
    end

    //reg file connections
    always_comb begin
        rf_if.clk = core_if.clk;
        if(core_if.core_halt) begin
            rf_if.reg_write = 1'b0;
            if(core_if.debug_controller_instruction == 8'h01) begin
                rf_if.rs1_addr = core_if.debug_address;
            end
        end
        else begin
            rf_if.rs1_addr = dec_if.rs1_addr;
            rf_if.rs2_addr = dec_if.rs2_addr;
            rf_if.rd_addr = dec_if.rd_addr;
            rf_if.reg_write = dec_if.reg_write;
        end
    end

    //reg file write select
    always_comb begin
        case (dec_if.wb_sel)
        2'b00:
            rf_if.write_data = alu_if.out_data;
        2'b01:
            rf_if.write_data = core_if.memory_read;
        2'b10:
            rf_if.write_data = pc_plus4;
        default:
            rf_if.write_data = alu_if.out_data;
        endcase
    end

    //decodder and sign extender connections
    always_comb begin
        dec_if.instruction = core_if.rom_read;
        se_if.sign_extender_opcode = core_if.rom_read[6:0];
        se_if.instruction_input = core_if.rom_read;
    end

    //branch unit connections
    always_comb begin
        bu_if.branch_flag = dec_if.branch_flag;
        bu_if.branch_opcode = dec_if.branch_opcode;
        bu_if.input_0 = rf_if.rs1_data;
        bu_if.input_1 = rf_if.rs2_data;
    end

    //memory connections
    always_comb begin
        if(core_if.core_halt) begin
            core_if.memory_write_en = 1'b0;
            if(core_if.debug_controller_instruction == 8'h02) begin
                core_if.memory_address = core_if.debug_address;
            end
        end
        else begin
            core_if.memory_write_en = dec_if.mem_write;
            core_if.memory_address = alu_if.out_data[ADDR_WIDTH-1:0];
            core_if.memory_write = rf_if.rs2_data;
        end
    end

    always_comb begin
        if(core_if.core_halt) begin
            unique case(core_if.debug_controller_instruction)
                8'h01: core_if.debug_data_return = rf_if.rs1_data;
                default core_if.debug_data_return = '0;
            endcase
        end
        else begin
            core_if.debug_data_return = '0;
        end
    end
endmodule
