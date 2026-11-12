// GPIO Wrapper for Synthesis
`default_nettype none

module gpio_synth_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10, 
    parameter GPIO_WIDTH = 10
)
(
    input logic clk,
    input logic rst_n,
    // IO interface
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic we,
    input logic sel,
    output logic [DATA_WIDTH-1:0] rdata,
    // GPIO interface
    input logic [GPIO_WIDTH-1:0] gpio_in,
    output logic [GPIO_WIDTH-1:0] gpio_out,
    output logic [GPIO_WIDTH-1:0] gpio_oe
);

gpio_interface #(.GPIO_WIDTH(GPIO_WIDTH)) gpio_if();
io_interface #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) io_if();

assign gpio_if.clk = clk;
assign gpio_if.rst_n = rst_n;
assign gpio_if.gpio_in = gpio_in;
assign gpio_out = gpio_if.gpio_out;
assign gpio_oe = gpio_if.gpio_oe;

assign io_if.addr = addr;
assign io_if.wdata = wdata;
assign io_if.we = we;
assign io_if.sel = sel;
assign rdata = io_if.rdata;

gpio #(.GPIO_WIDTH(GPIO_WIDTH), .DATA_WIDTH(DATA_WIDTH)) u_gpio (.gpio_if(gpio_if), .bus(io_if));

endmodule

`default_nettype wire