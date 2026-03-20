/*
* alu module executes all logical and arithmetic instructions.
* Using alu_interfacce to define ports. Essentailly a mux that
* outputs the correct line for the operation being done.
*/
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