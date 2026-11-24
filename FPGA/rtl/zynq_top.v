module zynq_top (
    input  wire       clk,
    input  wire       rst_n,
    output wire [6:0] led,    // GPIO[6:0] -> 7 White LEDs
    inout  wire [2:0] pmod,   // GPIO[9:7] -> 3 Bidirectional PMOD pins
    output wire       tx,
    input  wire       rx
);
    wire [6:0] led_w;

    soc_flash_wrapper soc (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (rx),
        .tx         (tx),
        .gpio_inout ({pmod, led_w})  // Bits [9:7] = pmod, Bits [6:0] = led_w
    );

    assign led = led_w;

endmodule