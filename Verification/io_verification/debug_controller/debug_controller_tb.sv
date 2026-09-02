/*
* alu_tb is the top level testbench for the alu
*/
`include "debug_controller_packet.sv"
`timescale 1ns/1ps
module alu_tb;


    //interface
    debug_interface debug_if();

    //DUT
    debug_controller DUT (
        .debug_if(debug_if.debug_dut)
    );

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results agianst expected output
    function bit expected_result(debug_controller_packet data);
        bit error;
        bit [7:0] debug_state_expected;
        
        return error;
    endfunction
    
    //test begins
    initial begin
        debug_controller_packet debug_controller_item = new();
        
        $display("[DEBUG CONTROLLER STATE TEST START]");

            alu_item.out_data = alu_if.out_data;

            //error counter
            error_counter = error_counter + expected_result(debug_controller_item);

        
        //display results
        $display("[DEBUG TEST COMPLETE]");
        $display("Total Errors: %d", error_counter);
        $finish;
    end


endmodule
