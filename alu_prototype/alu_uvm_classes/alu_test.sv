class alu_test extends uvm_test;

    `uvm_component_utils(alu_test)
    function new(string name = "alu_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    alu_env env;
    alu_sequence seq;

    //virtual interfaces
    //clk interface for testing only
    virtual alu_interface alu_vif;
    virtual clk_interface clk_vif;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = alu_env::type_id::create("env", this);
        if(!uvm_config_db#(virtual alu_interface)::get(this, "", "alu_interface", alu_vif))
            `uvm_fatal("DRV", "No alu_vif found")
        if(!uvm_config_db#(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
            `uvm_fatal("DRV", "No clk_vif found")

        seq = alu_sequence::type_id::create("seq");
        seq.randomize();
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask

    

endclass
