// alu.sv
`timescale 1ns/1ps

module alu(alu_interface.alu_dut alu_if);
    localparam int WIDTH = $bits(alu_if.in_data_0);

    // signed/unsigned
    logic [WIDTH-1:0]        a_u, b_u;
    logic signed [WIDTH-1:0] a_s, b_s;
    logic [WIDTH-1:0]        result;

    // Op-Casting
    always_comb begin
    a_u = alu_if.in_data_0;
    b_u = alu_if.in_data_1;
    a_s = $signed(alu_if.in_data_0);
    b_s = $signed(alu_if.in_data_1);
    end

    // combinational logic
    always_comb begin
        result = '0; //default result = '0;
        unique case(alu_if.alu_opcode)
        /*
        ADD
        SUB

        AND
        OR
        XOR

        SLL
        SRL
        SRA

        SLT
        SLTU

        PASSTHROUGH
        */

        default: result = '0;
        endcase
    end
endmodule