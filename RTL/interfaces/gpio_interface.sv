/*
* Interface for the GPIO peripheral's clock, reset and pin side. The bus
* side (register reads/writes) goes through io_interface instead.
*
* Each pin is split into in / out / oe (output enabled) rather than an inout: the pad cell
* at the chip boundary combines them into a bidirectional pin, which keeps
* tristates out of the core logic.
*/
`timescale 1ns/1ps
interface gpio_interface #(
    parameter int GPIO_WIDTH = 10 //10 pins for GPIO
)();

    logic clk;
    logic rst_n;

    logic [GPIO_WIDTH-1:0] gpio_in;   // from pads, asynchronous to clk
    logic [GPIO_WIDTH-1:0] gpio_out;  // to pads, value driven when oe = 1
    logic [GPIO_WIDTH-1:0] gpio_oe;   // to pads, 1 = output, 0 = input (high-Z)

    modport gpio_dut
    (
        input  clk,
        input  rst_n,
        input  gpio_in,
        output gpio_out,
        output gpio_oe
    );

endinterface
