/*
*   soc_tb.sv is the top level testbench for the soc module.
*
*   INFO: relplace debug_test.hex with actual file path
*/
`timescale 1ns/1ps

module soc_tb;
    //imports test components
    import test_package::*;

    //tb clk
    bit clk = 0;
    always #5 clk = ~clk;
    soc_interface soc_if();
    core_probe core_probe_if();

    always_comb begin
        soc_if.clk = clk;
    end

    //module instance
    soc #(
          .ROM_INITIAL_FILE("debug_test.hex")
        )
        soc_dut(.soc_if(soc_if.soc_io));

    assign core_probe_if.registers = soc_dut.core0.u_register_file.registers;
    assign core_probe_if.memory = soc_dut.core0.ram.ram;
    assign core_probe_if.core_halt = soc_dut.core0_if.core_halt;

    initial begin
        soc_test test0;
        
        soc_if.rx = 1'b1;

        //run test and starts all components
        test0 = new;
        test0.env.soc_vif = soc_if;
        test0.env.core_probe_vif = core_probe_if;
        test0.run();
        
        //ensure core is actually executing instructions
        #200;
        $finish;
    end

endmodule

