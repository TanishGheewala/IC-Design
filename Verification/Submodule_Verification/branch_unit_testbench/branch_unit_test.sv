/*
* brnach_unit_testbench is the top level testbench for the branch unit
*/
`include "branch_unit_packet.sv"
`timescale 1ns/1ps
module branch_unit_tb;


    //interface
    branch_unit_interface bu_if();

    //DUT
    branch_unit DUT (
        .bu_if(bu_if.bu_dut)
    );

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results agianst expected output
    function bit expected_result(branch_unit_packet data);
        bit error;
        bit expected;

        case (data.branch_opcode)

            3'b000: expected = (data.input_0 == data.input_1) & data.branch_flag;

            3'b001: expected = (data.input_0 != data.input_1) & data.branch_flag;
            3'b100: expected = ($signed(data.input_0) < $signed(data.input_1)) & data.branch_flag;
            3'b101: expected = ($signed(data.input_0) >= $signed(data.input_1)) & data.branch_flag;

            3'b110: expected = ($unsigned(data.input_0) < $unsigned(data.input_1)) & data.branch_flag;
            3'b111: expected = ($unsigned(data.input_0) >= $unsigned(data.input_1)) & data.branch_flag;
            3'b010: expected = 1'b1 & data.branch_flag;

            default: expected = 1'd0;

        endcase

        //prints error 
        //returns 0 for no error, 1 for errror
        //used in error count
        assert(data.output_flag === expected) begin
            error = 0;
        end else begin 
            $error("Expected Does not match Actual Value");
            data.print();
            error = 1;
        end
        
        return error;
    endfunction
    
    //test begins
    initial begin
        branch_unit_packet branch_unit_item = new();
        
        $display("[BRANCH UNIT TEST START]");

        //test 1000 random values
        repeat(1000) begin
            if (!branch_unit_item.randomize()) $fatal(1 ,"Randomization failed");

            bu_if.input_0  = branch_unit_item.input_0;
            bu_if.input_1  = branch_unit_item.input_1;
            bu_if.branch_opcode = branch_unit_item.branch_opcode;
            bu_if.branch_flag = branch_unit_item.branch_flag;

            #10;

            branch_unit_item.output_flag = bu_if.output_flag;

            //error counter
            error_counter = error_counter + expected_result(branch_unit_item);

        end
        
        //display results
        $display("[BRANCH UNIT TEST COMPLETE]");
        $display("Total Errors: %d", error_counter);
        $finish;
    end


endmodule
