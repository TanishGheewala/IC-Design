/*
 * alu_agent instantiates and connects the driver, sequencer,
 * and monitor. Configured as active (has a driver + sequencer).
 */
class alu_agent extends uvm_agent;

    `uvm_component_utils(alu_agent)


    alu_driver    drv;
    alu_monitor   mon;
    uvm_sequencer #(alu_item) seqr;

    // expose the monitor's analysis port so the env can connect
    // it to the scoreboard without reaching inside the agent
    uvm_analysis_port #(alu_item) agent_analysis_port;

    function new(string name = "alu_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // instantiate all child components
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = alu_driver   ::type_id::create("drv",  this);
        seqr = uvm_sequencer#(alu_item)::type_id::create("seqr", this);
        mon  = alu_monitor  ::type_id::create("mon",  this);
        agent_analysis_port = new("agent_analysis_port", this);
    endfunction

    // wire the driver's TLM port to the sequencer's export,
    // and forward the monitor's analysis port upward
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.mon_analysis_port.connect(agent_analysis_port);
    endfunction

endclass