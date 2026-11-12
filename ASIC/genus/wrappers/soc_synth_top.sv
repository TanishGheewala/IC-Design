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
    inout logic [9:0] gpio_inout
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

    //tri state logic for gpio pins
    genvar i;
    generate
        for (i = 0; i < 10; i++) begin : gen_gpio_pads
            assign gpio_inout[i] = soc_if.gpio_oe[i] ? soc_if.gpio_out[i] : 1'bz;
            assign soc_if.gpio_in[i] = gpio_inout[i];
        end
    endgenerate
    soc dut (
        .soc_if(soc_if)
    );
    
endmodule