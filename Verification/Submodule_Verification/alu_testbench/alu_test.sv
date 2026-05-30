/*
* alu_tb is the top level testbench for the alu
*/
`include "alu_packet.sv"
`timescale 1ns/1ps
module alu_tb;


    //interface
    alu_interface alu_if();

    //DUT
    alu DUT (
        .alu_if(alu_if.alu_dut)
    );

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results agianst expected output
    function bit expected_result(alu_packet data);
        bit error;
        bit [31:0] expected;

        case (data.alu_opcode)

            6'b011001: expected = data.in_data_0 + data.in_data_1;
            6'b011010: expected = data.in_data_0 - data.in_data_1;

            6'b011011: expected = data.in_data_0 & data.in_data_1;
            6'b011100: expected = data.in_data_0 | data.in_data_1;
            6'b011101: expected = data.in_data_0 ^ data.in_data_1;

            6'b011110: expected = data.in_data_0 << data.in_data_1[4:0];
            6'b011111: expected = data.in_data_0 >> data.in_data_1[4:0];
            6'b100000: expected = $signed(data.in_data_0) >>> data.in_data_1[4:0];

            6'b100001: expected = ($signed(data.in_data_0) < $signed(data.in_data_1)) ? 32'd1 : 32'd0;
            6'b100010: expected = (data.in_data_0 < data.in_data_1) ? 32'd1 : 32'd0;

            6'b100011: expected = data.in_data_0;
            6'b100100: expected = data.in_data_1;

            default: expected = 32'd0;

        endcase

        //prints error 
        //returns 0 for no error, 1 for errror
        //used in error count
        assert(data.out_data === expected) begin
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
        alu_packet alu_item = new();
        
        $display("[ALU TEST START]");

        //test 1000 random values
        repeat(1000) begin
            if (!alu_item.randomize()) $fatal(1 ,"Randomization failed");

            alu_if.in_data_0  = alu_item.in_data_0;
            alu_if.in_data_1  = alu_item.in_data_1;
            alu_if.alu_opcode = alu_item.alu_opcode;

            #10;

            alu_item.out_data = alu_if.out_data;

            //error counter
            error_counter = error_counter + expected_result(alu_item);

        end
        
        //display results
        $display("[ALU TEST COMPLETE]");
        $display("Total Errors: %d", error_counter);
        $finish;
    end


endmodule