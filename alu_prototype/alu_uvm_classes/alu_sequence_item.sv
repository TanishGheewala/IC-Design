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

    constraint c_alu_op { alu_op inside {6'b011001, 6'b011010, 6'b011011, 6'b011100, 6'b011101, 
                            6'b011110, 6'b011111, 6'b100000, 6'b100001, 6'b100010, 
                            6'b100011, 6'b100100};}

    //NEED A PRINT FUNCTION
    //currently looking into uvm_printer
    //if not uvm_printer then will create custom
    virtual function string item_string();
      return $sformatf("in0=%0d, in1=%0d, op=%b, out=%0d", in_data_0, in_data_1, alu_op, out_data);
    endfunction

    //must have for uvm integration
    //also for regisrering class
    //for identifing in logs and factory
    function new(string name = "alu_item");
		super.new(name);
	endfunction
endclass
