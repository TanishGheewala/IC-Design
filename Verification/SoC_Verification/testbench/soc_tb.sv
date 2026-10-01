/*
*   soc_tb.sv is the top level testbench for the soc module.
*/
`timescale 1ns/1ps

module soc_tb;
    //imports test components
    import test_package::*;

    //tb clk
    bit clk;
    always #10 clk = ~clk;
    soc_interface soc_if();

    always_comb begin
        soc_if.clk = clk;
    end

    //module instance
    soc #(
          .ROM_INITIAL_FILE("test_program.hex")
        )
        soc_dut(.soc_if(soc_if.soc_io));

    initial begin
        soc_test test0;
        
        clk <= 0;

        //run test and starts all components
        test0 = new;
        test0.env.soc_vif = soc_if;
        test0.run();

        #200 $finish;
    end

endmodule

