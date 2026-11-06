/*
* Interface for debug controller module. Defines all I/O ports.
*/
interface debug_interface_v2();

    //instruction input and cpu controll output
    logic clk;
    logic tx;
    logic rx;

    logic core_halt;
    logic [7:0] command;
    logic [31:0] core_data;

    logic write_en;
    logic [31:0] write_data;
    logic [31:0] data_address;

    logic bootl_done;

    //dut setup
    modport debug_dut
    (
        input clk,
        input rx,
        input core_data,
        input bootl_done,
        output tx,
        output core_halt,
        output command,
        output write_data,
        output write_en,
        output data_address
    );

endinterface
