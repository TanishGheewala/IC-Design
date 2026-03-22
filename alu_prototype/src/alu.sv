// alu.sv

`timescale 1ns/1ps

module alu(
    alu_interface.dut alu_if
);
    always_comb begin
        case(alu_if.alu_opcode)
        
            //define cases here
            //EX: 6'b011001: alu_if.out_data = alu_if.in_data_0 + alu_if.in_data_1;


        endcase
    end
endmodule