/*
* rv32i_instruction_item class is the barbones transaction item
* to be used in the uvm tests for the core. 
*/
class rv32i_instruction_item extends uvm_sequence_item;

//register with factory
`uvm_object_utils(rv32i_instruction_item);

//instruction_input
rand bit [31:0] instruction;

//simple to string functin for info when error printing
virtual function string item_string();
    return $sformatf("instruction: %0h", instruction);
endfunction

endclass
