/*
* soc_interface.sv is the interface for the top module of the chip.
*/
interface soc_interface();

    logic clk;
    logic rx;
    logic tx;
    logic [31:0] gpio_pins;

    modport soc_io (
        input clk,
        input rx,
        output tx,
        inout gpio_pins
    );
endinterface
