/*
 * component_test initializes the testing set up for a component. 
 * Uses uvm_factory to overide classes for components.
 */
class component_test extends uvm_test;

    `uvm_component_utils(component_test)
    function new(string name = "component_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    alu_env env;
    alu_sequence seq;

    //virtual interfaces
    //clk interface for testing only
    //REPLACE component_interface WITH MODULE INTERFACE WHEN TESTING
    virtual component_interface component_vif;
    virtual clk_interface clk_vif;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = alu_env::type_id::create("env", this);
        if(!uvm_config_db#(virtual comoponent_interface)::get(this, "", "component_interface", component_vif))
            `uvm_fatal("DRV", "No component_vif found")
        if(!uvm_config_db#(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
            `uvm_fatal("DRV", "No clk_vif found")

        //REPLACE ALL CHILD CLASSES WITH CORRESPONDING CLASS FOR COMPONENT BEING TESTED
        set_type_override_by_type(component_driver::get_type(), child_driver::get_type());
        set_type_override_by_type(component_monitor::get_type(), child_driver::get_type());
        set_type_override_by_type(component_scoreboard::get_type(), child_driver::get_type());
        set_type_override_by_type(component_sequence_item::get_type(), child_driver::get_type());

        //sequnece randomization
        seq = component_sequence::type_id::create("seq");
        seq.randomize();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask

    

endclass