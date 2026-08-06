/*
* Interface for sign extender, defines IO.
*/
interface sign_extender_interface();

    logic [6:0] sign_extender_opcode;
    
    logic [31:0] instruction_input;
    
    logic [31:0] immediate_output;

    //modport makes data direction clear for testing
    modport se_dut(
        input sign_extender_opcode,
        input instruction_input, 
        output immediate_output
    );
endinterface