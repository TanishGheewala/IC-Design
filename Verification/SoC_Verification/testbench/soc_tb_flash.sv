/*
*   soc_tb.sv is the top level testbench for the soc module.
*
*   INFO: relplace debug_test.hex with actual file path
*/
`timescale 1ns/1ps

module soc_tb_flash;
    //imports test components
    import test_package::*;

    //tb clk
    bit clk = 0;
    logic [9:0] gpio_input = 10'hFFF;
    always #5 clk = ~clk;
    soc_interface soc_if();
    core_probe core_probe_if();

    always_comb begin
        soc_if.clk = clk;
    end

    //module instance
    soc #(
          .ROM_INITIAL_FILE("")
        )
        soc_dut(.soc_if(soc_if.soc_io));
    
    spi_flash_model #(
        .MEM_BYTES(6144),
        .INIT_FILE("")
        )
        flash_memory(
            .sclk(soc_if.sclk),
            .mosi(soc_if.mosi),
            .miso(soc_if.miso),
            .cs_n(soc_if.cs_n)
        );

    assign core_probe_if.registers = soc_dut.core0.u_register_file.registers;
    assign core_probe_if.memory = soc_dut.data_memory.bank0.mem;
    assign core_probe_if.core_halt = soc_dut.core0_if.core_halt;
    assign core_probe_if.gpio_dir = soc_dut.gpio_block.dir_q;
    assign core_probe_if.gpio_out = soc_dut.gpio_block.out_q;
    assign core_probe_if.gpio_in = gpio_input;

    initial begin
        soc_test test0;
        gpio_input = 10'hFFF;
        soc_if.gpio_in = gpio_input;
        soc_if.rx = 1'b1;
        soc_if.rst_n = 0;
        repeat (3) @(posedge soc_if.clk);
        soc_if.rst_n = 1;

        //lets program run
        @(posedge soc_dut.boot_done); 
        #4000;

        //run test and starts all components
        test0 = new;
        test0.env.soc_vif = soc_if;
        test0.env.core_probe_vif = core_probe_if;
        test0.run();

        #200;
        $finish;
    end

endmodule

