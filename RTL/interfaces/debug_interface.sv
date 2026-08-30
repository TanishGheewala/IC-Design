/*
* Interface for debug controller module. Defines all I/O ports.
*/
interface debug_interface();

    //instruction input and cpu controll output
    logic clk;
    logic tx;
    logic rx;
    logic [7:0] debug_instruction;
    logic core_halt;
    logic [31:0] core_signals;
    logic [31:0] data_return_in;

    //dut setup
    modport debug_dut
    (
        input clk,
        input rx,
        input data_return_in,
        output tx,
        output core_halt,
        output core_signals
    );

endinterface
