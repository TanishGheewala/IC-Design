/*
* component_sequence_item is the base class all other component sequence_items derive from.
*
*/
class component_sequence_item extends uvm_sequence_item

    //required UVM setup
    `uvm_component_utils(component_sequence_item)
    function new(string name = "component_sequence_item", uvm_component parent=null);
        super.new(name, parent);
    endfunction

endclass