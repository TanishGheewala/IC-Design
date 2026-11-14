/*
* Interface for debug controller module. Defines all I/O ports.
*/
interface debug_interface_v2();

    //instruction input and cpu controll output
    logic clk;
    logic rst_n;
    logic tx;
    logic rx;

    logic core_halt;
    logic [7:0] command;
    logic [31:0] core_data;

    logic write_en;
    logic [31:0] write_data;
    logic [31:0] data_address;

    logic flash_write_done;
    logic flash_write_en;

    //dut setup
    modport debug_dut
    (
        input clk,
        input rx,
        input core_data,
        input flash_write_done,
        input rst_n,
        output tx,
        output core_halt,
        output command,
        output write_data,
        output write_en,
        output data_address,
        output flash_write_en
    );

endinterface
