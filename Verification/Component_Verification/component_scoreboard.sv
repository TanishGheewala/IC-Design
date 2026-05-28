/*
* component_scoreboard is the base class all other component scoreboards derive from.
*
*/
class component_scoreboard extends uvm_scoreboard

    //required UVM setup
    `uvm_component_utils(component_scoreboard)
    function new(string name = "component_scoreboard", uvm_component parent=null);
        super.new(name, parent);
    endfunction

endclass