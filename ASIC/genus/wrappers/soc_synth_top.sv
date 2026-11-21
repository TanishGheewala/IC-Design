/*
*   soc top module for cadence genus synth
*/
module soc_synth_top (
    input logic clk,
    input logic rst_n,
    input logic rx,
    output logic tx,
    output logic sclk,
    output logic mosi,
    input logic miso,
    output logic cs_n,
    input logic [9:0] gpio_in,
    output logic [9:0] gpio_out,
    output logic [9:0] gpio_oe
);

    soc_interface soc_if();

    assign soc_if.clk = clk;
    assign soc_if.rst_n = rst_n;
    assign soc_if.rx = rx;
    assign soc_if.miso = miso;

    assign tx = soc_if.tx;
    assign sclk = soc_if.sclk;
    assign mosi = soc_if.mosi;
    assign cs_n = soc_if.cs_n;

    //separate gpio pins
    assign soc_if.gpio_in = gpio_in;
    assign gpio_out = soc_if.gpio_out;
    assign gpio_oe = soc_if.gpio_oe;

    soc dut (
        .soc_if(soc_if)
    );
    
endmodule