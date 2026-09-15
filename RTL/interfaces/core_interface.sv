/*
* Interface for RISC V core
*/
interface core_interface();

    logic clk;
    logic rst_n;
    logic core_halt;
    logic [7:0] debug_controller_instruction;
    logic [31:0] debug_address;
    logic [31:0] debug_data_return;

    //dut setup
    modport dut
    (
        input clk,
        input rst_n,
        input core_halt,
        input debug_controller_instruction,
        input debug_address,
        output debug_data_return
    );

endinterface