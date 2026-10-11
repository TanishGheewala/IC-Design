/*
SPI INTERFACE

*/
`timescale 1ns/1ps

interface spi_interface();

    logic clk;
    logic rst_n;

    //SPI Signals
    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;
    
    modport spi_dut
    (
        input  clk,
        input  rst_n,
        output sclk,
        output mosi,
        input  miso,
        output cs_n
    );

endinterface