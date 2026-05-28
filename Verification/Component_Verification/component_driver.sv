/*
* component_driver is the base class all other component drivers derive from.
*
*/
class component_driver extends uvm_driver #(component_item);

    //required UVM setup
    `uvm_component_utils(component_driver)
    function new(string name = "component_driver", uvm_component parent=null);
        super.new(name, parent);
    endfunction

endclass
