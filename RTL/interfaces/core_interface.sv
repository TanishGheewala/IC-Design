/*
* Interface for RISC V core
*/
interface branch_unit_interface();

    //branch on/off
    logic clk;
    logic rst_n;
    logic debug_flag;

    //dut setup
    modport bu_dut
    (
        input clk,
        input rst_n
    );

endinterface