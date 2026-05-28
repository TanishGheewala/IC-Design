/*
* component_monitor is the base class all other component monitors derive from.
*
*/
class component_monitor extends uvm_monitor

    //required UVM setup
    `uvm_component_utils(component_monitor)
    function new(string name = "component_monitor", uvm_component parent=null);
        super.new(name, parent);
    endfunction

endclass