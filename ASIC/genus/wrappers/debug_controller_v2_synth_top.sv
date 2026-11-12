/*
*   Debug Controller v2 top module for cadence genus test synth
*/
module debug_controller_v2_synth_top (
    input logic clk,
    input logic rst_n,
    input logic rx,
    output logic tx,
    output logic core_halt,
    output logic [7:0] command,
    input logic [31:0] core_data,
    output logic write_en,
    output logic [31:0] write_data,
    output logic [31:0] data_address,
    input logic flash_write_done,
    output logic flash_write_en
);

    debug_interface_v2 debug_if();

    assign debug_if.clk = clk;
    assign debug_if.rst_n = rst_n;
    assign debug_if.rx = rx;
    assign debug_if.core_data = core_data;
    assign debug_if.flash_write_done = flash_write_done;

    assign tx = debug_if.tx;
    assign core_halt = debug_if.core_halt;
    assign command = debug_if.command;
    assign write_en = debug_if.write_en;
    assign write_data = debug_if.write_data;
    assign data_address = debug_if.data_address;
    assign flash_write_en = debug_if.flash_write_en;

    debug_controller_v2 dut (
        .debug_if(debug_if)
    );
endmodule