/*
*   for top level zynq design
*   
*/
module zynq_top (
    input wire clk,
    input wire rst_n,
    input wire rx,
    output wire tx,
    output wire led
);
    wire [9:0] gpio_inout;

    soc_flash_wrapper soc(
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .gpio_inout(gpio_inout)
    );

    assign led = gpio_inout;
    assign gpio_inout[9:1] = 0;

    
endmodule