/*
* soc_interface.sv is the interface for the top module of the chip.
*/
interface soc_interface #(
    parameter int GPIO_WIDTH = 10)
    ();

    logic clk;
    logic rx;
    logic tx;
    logic [GPIO_WIDTH-1:0] gpio_in;   
    logic [GPIO_WIDTH-1:0] gpio_out;
    logic [GPIO_WIDTH-1:0] gpio_oe;

    modport soc_io (
        input clk,
        input rx,
        input gpio_in,
        output tx,
        output gpio_out,
        output gpio_oe
    );
endinterface
