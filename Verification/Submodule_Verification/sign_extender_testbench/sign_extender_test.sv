/*
* sign_extencer_tb is the top level testbench for the alu
*/
`include "sign_extender_packet.sv"
`timescale 1ns/1ps
module sign_extencer_tb;


    //interface
    sign_extender_interface sign_ex_if();

    //DUT
    sign_extender DUT (
        .se_if(sign_ex_if.se_dut)
    );

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results agianst expected output
    function bit expected_result(sign_extender_packet data);
        bit error;
        bit [31:0] expected;

        case (data.se_opcode)

            //u type
            7'b0110111, 
            7'b0010111: expected = $signed({data.instruct_non_op[24:5], {12{1'b0}}});

            //j type
            7'b1101111: expected = $signed({data.instruct_non_op[24], data.instruct_non_op[12:5],
                                            data.instruct_non_op[13], data.instruct_non_op[23:14], 1'b0}); 

            //b type
            7'b1100011: expected = $signed({data.instruct_non_op[24], data.instruct_non_op[0],
                                            data.instruct_non_op[23:18], data.instruct_non_op[4:1], 1'b0}); 

            //s type
            7'b0100011: expected = $signed({data.instruct_non_op[24:18], data.instruct_non_op[4:0]}); 
            
            //i type
            7'b1100111,
            7'b0000011, 
            7'b0010011: expected = $signed(data.instruct_non_op[24:13]);

            //r type
            7'b0110011: expected = 32'd0;

            default: expected = 32'd0;

        endcase

        //prints error 
        //returns 0 for no error, 1 for errror
        //used in error count
        assert(data.imme_out === expected) begin
            error = 0;
        end else begin 
            $error("Expected Does not match Actual Value: expected = %0h", expected);
            data.print();
            error = 1;
        end
        
        return error;
    endfunction
    
    //test begins
    initial begin
        sign_extender_packet sign_extender_item = new();
        
        $display("[SIGN EXTENDER TEST START]");

        //test 1000 random values
        repeat(1000) begin
            if (!sign_extender_item.randomize()) $fatal(1 ,"Randomization failed");

            sign_ex_if.sign_extender_opcode = sign_extender_item.se_opcode;
            sign_extender_item.instruct_data = {sign_extender_item.instruct_non_op, sign_extender_item.se_opcode};
            sign_ex_if.instruction_input  = sign_extender_item.instruct_data;

            #10;

            sign_extender_item.imme_out = sign_ex_if.immediate_output;

            //error counter
            error_counter = error_counter + expected_result(sign_extender_item);

        end
        
        //display results
        $display("[SIGN EXTENDER TEST COMPLETE]");
        $display("Total Errors: %d", error_counter);
        $finish;
    end
 

endmodule