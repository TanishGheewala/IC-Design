/*
 * component_env instantiates the agent and scoreboard, sets virtual
 * interfaces into the config DB, and wires analysis ports.
 */
class component_env extends uvm_env;

    `uvm_component_utils(component_env)

    function new(string name = "component_env", uvm_component parent = null);
            super.new(name, parent);
    endfunction

    component_agent      agent;
    component_scoreboard scoreboard;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = conmponent_agent::type_id::create("agent", this);
        scoreboard = component_scoreboard::type_id::create("scoreboard", this);
    endfunction

    // connect the agent's forwarded analysis port to the scoreboard
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.mon_analysis_port.connect(scoreboard.ap_imp);
    endfunction

endclass