/*
* soc_interface.sv is the interface for the top module of the chip.
*/
interface soc_interface #(
    parameter int GPIO_WIDTH = 10)
    ();

    logic clk;

    //uart
    logic rx;
    logic tx;

    //spi
    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;
    
    //gpio
    logic [GPIO_WIDTH-1:0] gpio_in;   
    logic [GPIO_WIDTH-1:0] gpio_out;
    logic [GPIO_WIDTH-1:0] gpio_oe;

    logic rst_n;

    modport soc_io (
        input clk,
        input rx,
        input gpio_in,
        output tx,
        output gpio_out,
        output gpio_oe,
        output sclk,
        output mosi,
        input  miso,
        output cs_n,
        input rst_n
    );
endinterface
