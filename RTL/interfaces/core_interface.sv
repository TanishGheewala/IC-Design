/*
* Interface for RISC V core
*/
interface branch_unit_interface();

    //branch on/off
    logic clk;
    logic rst_n;
    logic core_halt;
    logic [7:0] debug_controller_instruction;
    logic [31:0] debug_data_return;

    //dut setup
    modport bu_dut
    (
        input clk,
        input rst_n,
        input core_halt,
        input debug_controller_instruction,
        output debug_data_return
        
    );

endinterface