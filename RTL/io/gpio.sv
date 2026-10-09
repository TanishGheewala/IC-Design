// gpio.sv - Memory-mapped general purpose I/O
//
// Sits in one slot of the I/O window behind io_decoder. Register map
// (byte offsets within the slot, one bit per pin, bits above GPIO_WIDTH
// read as 0 and ignore writes):
//
//   0x00  DIR  RW  1 = pin is an output, 0 = input. Resets to 0 so no pin
//                  drives until software configures it.
//   0x04  OUT  RW  value driven on pins whose DIR bit is 1. Resets to 0.
//   0x08  IN   RO  synchronized pin levels; writes are ignored.
//
// Unmapped offsets read 0 and ignore writes. Reads are combinational and
// writes take effect on the next clock edge, matching data_memory, so a
// load/store to GPIO behaves exactly like one to RAM in the single-cycle
// datapath.

`timescale 1ns/1ps

module gpio #(
    parameter int GPIO_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    gpio_interface.gpio_dut gpio_if,
    io_interface.io_dev     bus
);

    localparam int REG_DIR = 'h00;
    localparam int REG_OUT = 'h04;
    localparam int REG_IN  = 'h08;

    if (GPIO_WIDTH > DATA_WIDTH)
        $error("gpio: GPIO_WIDTH=%0d does not fit in a %0d-bit register", GPIO_WIDTH, DATA_WIDTH);

    logic [GPIO_WIDTH-1:0] dir_q;
    logic [GPIO_WIDTH-1:0] out_q;
    logic [GPIO_WIDTH-1:0] in_meta, in_sync;

    // Pins change asynchronously to clk; two flops let a first
    // stage settle before the value reaches the core.
    always_ff @(posedge gpio_if.clk) begin
        if (!gpio_if.rst_n) begin
            in_meta <= '0;
            in_sync <= '0;
        end else begin
            in_meta <= gpio_if.gpio_in;
            in_sync <= in_meta;
        end
    end

    always_ff @(posedge gpio_if.clk) begin
        if (!gpio_if.rst_n) begin
            dir_q <= '0;
            out_q <= '0;
        end else if (bus.sel && bus.we) begin
            case (bus.addr)
                REG_DIR: dir_q <= bus.wdata[GPIO_WIDTH-1:0];
                REG_OUT: out_q <= bus.wdata[GPIO_WIDTH-1:0];
                default: ;
            endcase
        end
    end

    always_comb begin
        bus.rdata = '0;
        case (bus.addr)
            REG_DIR: bus.rdata[GPIO_WIDTH-1:0] = dir_q;
            REG_OUT: bus.rdata[GPIO_WIDTH-1:0] = out_q;
            REG_IN:  bus.rdata[GPIO_WIDTH-1:0] = in_sync;
            default: ;
        endcase
    end

    assign gpio_if.gpio_out = out_q;
    assign gpio_if.gpio_oe  = dir_q;

endmodule
