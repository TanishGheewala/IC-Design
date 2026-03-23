// alu.sv
`timescale 1ns/1ps

module alu(alu_interface.dut alu_if);
//Move some of this out to alu_interface later
    localparam int WIDTH = $bits()//;
    // signed/unsigned
    logic [WIDTH-1:0]        a_u, b_u;
    logic signed [WIDTH-1:0] a_s, b_s;
    logic [WIDTH-1:0]        result;
    logic [WIDTH-1:0]        result_s;

    // op casting

    // combinational logic
    always_comb begin
        result = '0; //default result = '0;
        unique case(alu_if.alu_opcode)

            //define cases here
            //EX: 6'b011001: alu_if.out_data = alu_if.in_data_0 + alu_if.in_data_1;

        default: result = '0;
        endcase
    end
endmodule