/*
* UVM sequence item, i.e. data format to be sent to module
* and other uvm components/objects. Should have the same data layout
* as interface for module being tested.
*/
class alu_item extends uvm_sequence_item;

    //must have for uvm integration
    //registers class with factory
    `uvm_object_utils(alu_item)

    //ports for data packet - must match interface
    //rand prefix allows data to be randomized when calling rand on class
    rand bit[5:0] alu_op;
    rand bit[31:0] in_data_0;
    rand bit[31:0] in_data_1;
    bit[31:0] out_data;

    //NEED A PRINT FUNCTION
    //currently looking into uvm_printer
    //if not uvm_printer then will create custom

    //must have for uvm integration
    //also for regisrering class
    //for identifing in logs and factory
    function new(string name = "alu_item");
		super.new(name);
	endfunction
endclass
