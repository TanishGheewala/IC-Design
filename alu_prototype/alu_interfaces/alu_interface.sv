/*
* Inteface for alu module. Defines all I/O ports.
*/
interface alu_interface();

    //alu opcode
    logic [5:0] alu_opcode;
    //operands
    logic [31:0] in_data_0;
    logic [31:0] in_data_1;

    //output from execution
    logic [31:0] out_data;

    //modport makes data direction clear for testing
    modport alu_dut(
        input alu_opcode,
        input in_data_0,
        input in_data_1,
        output out_data
    );
endinterface
