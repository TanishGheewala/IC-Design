/*
 * alu_env instantiates the agent and scoreboard, sets virtual
 * interfaces into the config DB, and wires analysis ports.
 */
class alu_env extends uvm_env;

    `uvm_component_utils(alu_env)

    alu_agent      agent;
    alu_scoreboard scoreboard;

    // virtual interfaces are passed in from the testbench top
    virtual alu_interface alu_vif;
    virtual clk_interface clk_vif;

    function new(string name = "alu_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // retrieve interfaces set by testbench top
        if(!uvm_config_db #(virtual alu_interface)::get(this, "", "alu_interface", alu_vif))
            `uvm_fatal("ENV", "No alu_vif found in config DB")
        if(!uvm_config_db #(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
            `uvm_fatal("ENV", "No clk_vif found in config DB")

        // push interfaces down so driver and monitor can retrieve them
        uvm_config_db #(virtual alu_interface)::set(this, "*", "alu_interface", alu_vif);
        uvm_config_db #(virtual clk_interface)::set(this, "*", "clk_interface", clk_vif);

        agent      = alu_agent     ::type_id::create("agent",      this);
        scoreboard = alu_scoreboard::type_id::create("scoreboard", this);
    endfunction

    // connect the agent's forwarded analysis port to the scoreboard
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.agent_analysis_port.connect(scoreboard.ap_imp);
    endfunction

endclass