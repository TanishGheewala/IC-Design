/*
*   soc_tb.sv is the top level testbench for the soc module (netlist GLS).
*
*   INFO: replace debug_test.hex with actual file path
*/
`timescale 1ns/1ps

module soc_netlist_tb;
    //imports test components
    import gls_package::*;

    //tb clk
    bit clk = 0;
    always #10 clk = ~clk;

    soc_interface soc_if();
    core_probe core_probe_if();

    wire tx;
    wire sclk;
    wire mosi;
    wire miso;
    wire cs_n;

    //the P&R netlist has separate gpio_in / gpio_out / gpio_oe pins (no inout),
    //so the tb models the pad: when oe=1 the pin carries the chip's gpio_out,
    //otherwise it carries the tb stimulus (soc_if.gpio_in). The chip's gpio_in
    //sees the pin, the same as reading back a bidirectional pad.
    wire [9:0] gpio_out;
    wire [9:0] gpio_oe;
    wire [9:0] gpio_pins;

    genvar g;
    generate
        for (g = 0; g < 10; g++) begin : gpio_pad
            assign gpio_pins[g] = (gpio_oe[g] === 1'b1) ? gpio_out[g] : soc_if.gpio_in[g];
        end
    endgenerate

    //wire tb interface to netlist ports
    assign soc_if.clk = clk;
    assign soc_if.tx = tx;
    assign soc_if.sclk = sclk;
    assign soc_if.mosi = mosi;
    assign soc_if.miso = miso;
    assign soc_if.cs_n = cs_n;
    assign soc_if.gpio_out = gpio_out;
    assign soc_if.gpio_oe = gpio_oe;

    //module instance
    soc_synth_top dut (
        .clk(clk),
        .rst_n(soc_if.rst_n),
        .rx(soc_if.rx),
        .tx(tx),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .gpio_in(gpio_pins),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe)
    );

    spi_flash_model #(
        .MEM_BYTES(6144),
        .INIT_FILE(""),
        .DUMP_FILE("")
    )
    flash_memory(
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    //register file probes from netlist wires (x0 is hardwired 0)
    assign core_probe_if.registers[0]  = 32'd0;
    assign core_probe_if.registers[1]  = dut.dut.core0.u_register_file.\registers[1] ;
    assign core_probe_if.registers[2]  = dut.dut.core0.u_register_file.\registers[2] ;
    assign core_probe_if.registers[3]  = dut.dut.core0.u_register_file.\registers[3] ;
    assign core_probe_if.registers[4]  = dut.dut.core0.u_register_file.\registers[4] ;
    assign core_probe_if.registers[5]  = dut.dut.core0.u_register_file.\registers[5] ;
    assign core_probe_if.registers[6]  = dut.dut.core0.u_register_file.\registers[6] ;
    assign core_probe_if.registers[7]  = dut.dut.core0.u_register_file.\registers[7] ;
    assign core_probe_if.registers[8]  = dut.dut.core0.u_register_file.\registers[8] ;
    assign core_probe_if.registers[9]  = dut.dut.core0.u_register_file.\registers[9] ;
    assign core_probe_if.registers[10] = dut.dut.core0.u_register_file.\registers[10] ;
    assign core_probe_if.registers[11] = dut.dut.core0.u_register_file.\registers[11] ;
    assign core_probe_if.registers[12] = dut.dut.core0.u_register_file.\registers[12] ;
    assign core_probe_if.registers[13] = dut.dut.core0.u_register_file.\registers[13] ;
    assign core_probe_if.registers[14] = dut.dut.core0.u_register_file.\registers[14] ;
    assign core_probe_if.registers[15] = dut.dut.core0.u_register_file.\registers[15] ;
    assign core_probe_if.registers[16] = dut.dut.core0.u_register_file.\registers[16] ;
    assign core_probe_if.registers[17] = dut.dut.core0.u_register_file.\registers[17] ;
    assign core_probe_if.registers[18] = dut.dut.core0.u_register_file.\registers[18] ;
    assign core_probe_if.registers[19] = dut.dut.core0.u_register_file.\registers[19] ;
    assign core_probe_if.registers[20] = dut.dut.core0.u_register_file.\registers[20] ;
    assign core_probe_if.registers[21] = dut.dut.core0.u_register_file.\registers[21] ;
    assign core_probe_if.registers[22] = dut.dut.core0.u_register_file.\registers[22] ;
    assign core_probe_if.registers[23] = dut.dut.core0.u_register_file.\registers[23] ;
    assign core_probe_if.registers[24] = dut.dut.core0.u_register_file.\registers[24] ;
    assign core_probe_if.registers[25] = dut.dut.core0.u_register_file.\registers[25] ;
    assign core_probe_if.registers[26] = dut.dut.core0.u_register_file.\registers[26] ;
    assign core_probe_if.registers[27] = dut.dut.core0.u_register_file.\registers[27] ;
    assign core_probe_if.registers[28] = dut.dut.core0.u_register_file.\registers[28] ;
    assign core_probe_if.registers[29] = dut.dut.core0.u_register_file.\registers[29] ;
    assign core_probe_if.registers[30] = dut.dut.core0.u_register_file.\registers[30] ;
    assign core_probe_if.registers[31] = dut.dut.core0.u_register_file.\registers[31] ;

    //other soc probes
    assign core_probe_if.memory = dut.dut.data_memory.bank0.mem;
    assign core_probe_if.core_halt = dut.dut.core0_if_core_halt;
    assign core_probe_if.gpio_dir = gpio_oe;
    assign core_probe_if.gpio_out = gpio_out;
    assign core_probe_if.gpio_in = gpio_pins;
    assign core_probe_if.flash_write_done = dut.dut.flash_write_done;
    assign core_probe_if.boot_done = dut.dut.boot_done;
    //pc: P&R renamed the pc nets, so read the pc_reg flop outputs (only pc[12:0] exist)
    assign core_probe_if.pc = {19'd0, dut.dut.core0.\pc_reg[12] .Q, dut.dut.core0.\pc_reg[11] .Q, dut.dut.core0.\pc_reg[10] .Q, dut.dut.core0.\pc_reg[9] .Q, dut.dut.core0.\pc_reg[8] .Q, dut.dut.core0.\pc_reg[7] .Q, dut.dut.core0.\pc_reg[6] .Q, dut.dut.core0.\pc_reg[5] .Q, dut.dut.core0.\pc_reg[4] .Q, dut.dut.core0.\pc_reg[3] .Q, dut.dut.core0.\pc_reg[2] .Q, dut.dut.core0.\pc_reg[1] .Q, dut.dut.core0.\pc_reg[0] .Q};

    initial begin
        gls_test test0;
        soc_if.gpio_in = 10'h3FF;
        soc_if.rx = 1'b1;
        soc_if.rst_n = 0;
        repeat (5) @(posedge clk);
        soc_if.rst_n = 1;

        //lets program run
        @(posedge dut.dut.boot_done);
        #4000;

        //run test and starts all components
        test0 = new;
        test0.env.soc_vif = soc_if;
        test0.env.core_probe_vif = core_probe_if;
        test0.run();

        #200;
        $display("PC: %0h", core_probe_if.pc);

        $finish;
    end

endmodule