/*
*   soc + flash wrapper for vivado block design to connect to arm core on zynq platform
*   
*   using direct connection to spi in wrapper so no need to
^   have spi pins output
*/
module soc_flash_wrapper (
    input wire clk,
    input wire rst_n,
    input wire rx,
    output wire tx,
    inout wire [9:0] gpio_inout
);

    //gpio and flash wries
    wire [9:0] gpio_in;
    wire [9:0] gpio_out;
    wire [9:0] gpio_oe;
    wire sclk;
    wire mosi;
    wire miso;
    wire cs_n;

    //soc
    soc_synth_top soc(
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe)
    );

    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : gen_gpio_pads
            assign gpio_inout[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;
            assign gpio_in[i] = gpio_inout[i];
        end
    endgenerate

    //flash model with 6KB mem
    spi_flash_model #(
        .MEM_BYTES(6144),
        .INIT_FILE("/home/tachyon/senior_design/FPGA/programs/flash_led.hex")
    )
    flash_memory(
        .clk(clk),
        .rst_n(rst_n),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );
    
endmodule