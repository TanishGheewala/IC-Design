/*
* soc.sv is the top most module of the chip. It will contain all the modules making up the ASIC.
*/

`timescale 1ns/1ps
`include "../memory/macros.vh"

module soc(input clk, input rx, output logic tx);

    core_interface core0_if();
    debug_interface debug_if();
    
    debug_controller debug_con(.core_if(core_if));
    core #(
        .ADDR_WIDTH(`ADDR_WIDTH),
        .MEM_DEPTH(`MEM_DEPTH),
        .ROM_INITIAL_FILE("test_program.hex"),
        .RAM_INITIAL_FILE(""),
        .DEBUG_PRINT(1'b0)
    )

    core0(.core_if(core0_if));

    //top level connections to modules
    always_comb begin
        debug_if.clk = clk;
        debug_if.rx = rx;
        tx = debug_if.tx;
        core0_if.clk = clk;
    end

    //intermodule conntections
    always_comb begin
        debug_if.data_return_in = core0_if.debug_data_return;
        core0_if.clk = clk;
        core0_if.debug_controller_instruction = debug_if.core_signals;
        core0_if.debug_address = debug_if.debug_address;
        core0_if.core_halt = debug_if.core_halt;
    end

endmodule