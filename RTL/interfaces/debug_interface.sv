/*
* Interface for debug controller module. Defines all I/O ports.
*/
interface debug_interface();

    //instruction input and cpu controll output
    logic [4:0] debug_instruction;
    logic core_halt;
    logic [31:0] core_signals;
    logic [31:0] data_return_in;
    logic [31:0] data_return_out;

    //dut setup
    modport debug_dut
    (
        input debug_instruction,
        input data_return_in,
        output core_halt,
        output core_signals,
        output data_return_out
    );

endinterface
