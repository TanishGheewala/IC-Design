/*
* Interface for brnach unit module. Defines all I/O ports.
*/
interface branch_unit_interface();

    //branch on/off
    logic branch_flag;
    //select branch operation
    logic [2:0] branch_opcode;
    //inputs
    logic [31:0]input_0;
    logic [31:0] input_1;

    //output flag
    logic output_flag;

    //dut setup
    modport bu_dut
    (
        input branch_flag,
        input branch_opcode,
        input input_0,
        input input_1,
        output output_flag
    );

endinterface
