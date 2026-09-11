/*
* RISC V core top module
*/
`timescale 1ns/1ps
`include "memory/macros.vh"

module core #(
    parameter ADDR_WIDTH = `ADDR_WIDTH,
    parameter MEM_DEPTH = `MEM_DEPTH,
    parameter ROM_INITIAL_FILE = "test_program.hex",
    parameter RAM_INITIAL_FILE = "",
    parameter DEBUG_PRINT = 1'b1
)
(core_interface.dut core_if);
    
    //interfaces
    instruction_memory_interface #(.ADDR_WIDTH(ADDR_WIDTH)) 
        rom_if();

    data_memory_interface #(.ADDR_WIDTH(ADDR_WIDTH)) 
        ram_if();

    decoder_interface       dec_if();
    register_file_interface rf_if();
    sign_extender_interface se_if();
    alu_interface           alu_if();
    branch_unit_interface   bu_if();

    //pc register & multiplexor variables
    logic [ADDR_WIDTH-1:0] pc = 0;
    logic [ADDR_WIDTH-1:0] pc_next = 0;
    logic [ADDR_WIDTH-1:0] pc_plus4;
    logic [ADDR_WIDTH-1:0] pc_plus_imm;
    logic take_branch;

    //core submodules
    instruction_memory #(
                       .ADDR_WIDTH(ADDR_WIDTH),
                       .MEM_DEPTH(MEM_DEPTH),
                       .MEM_INITIAL_FILE(ROM_INITIAL_FILE)
                        ) 
        rom (
            .addr(rom_if.addr),
            .inst(rom_if.inst)
        );

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

    data_memory #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .MEM_DEPTH(MEM_DEPTH),
                .MEM_INITIAL_FILE(RAM_INITIAL_FILE)
                ) 
        ram (
            .clk(clk),
            .we(ram_if.we),
            .addr(ram_if.addr),
            .data_in(ram_if.data_in),
            .data_out(ram_if.data_out)
        );

    //pc update
    always_ff @(posedge core_if.clk) begin
        if (!core_if.rst_n)
            pc <= '0;
        else
            pc <= pc_next;
    end

    //pc updatae logic 
    always_comb begin
        take_branch = dec_if.branch_flag && bu_if.output_flag;
        if(core_if.core_halt) begin
            pc_next = pc;
        end
        else begin
            if (take_branch) begin
                if (dec_if.jump_flag && dec_if.alu_src) begin
                    pc_next = alu_if.out_data[ADDR_WIDTH-1:0]; // JALR
                end
                else begin
                    pc_next = pc + se_if.immediate_output[ADDR_WIDTH-1:0];
                end
                end
            else begin
            pc_next = pc + 4;
            end
        end
    end

    //alu connections
    always_comb begin
        alu_if.alu_opcode = dec_if.alu_opcode;

        //multiplexors for input
        if(dec_if.alu_a_src) begin
            alu_if.in_data_0 = {{(32-ADDR_WIDTH){1'b0}}, pc};
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
        rf_if.clk = clk;
        if(core_if.core_halt) begin
        end
        else begin
            rf_if.rs1_addr = dec_if.rs1_addr;
            rf_if.rs2_addr = dec_if.rs2_addr;
            rf_if.rd_addr = dec_if.rd_addr;
            rf_if.reg_write = dec_if.reg_write;
        end
    end

    //decodder and sign extender connections
    always_comb begin
        dec_if.instruction = rom_if.inst;
        se_if.sign_extender_opcode = rom_if.inst[6:0];
        se_if.instruction_input = rom_if.inst;
    end

    //branch unit connections
    always_comb begin
        bu_if.branch_flag = dec_if.branch_flag;
        bu_if.branch_opcode = dec_if.branch_opcode;
        bu_if.input_0 = rf_if.rs1_data;
        bu_if.input_1 = rf_if.rs2_data;
    end

    //ram connections
    always_comb begin
        if(core_if.core_halt) begin
        end
        else begin
            ram_if.we = dec_if.mem_write;
            ram_if.addr = alu_if.out_data[ADDR_WIDTH-1:0];
            ram_if.data_in = rf_if.rs2_data;
        end
    end
endmodule
