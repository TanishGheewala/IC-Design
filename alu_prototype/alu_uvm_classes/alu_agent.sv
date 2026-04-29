/*
 * alu_agent instantiates and connects the driver, sequencer,
 * and monitor. Configured as active (has a driver + sequencer).
 */
class alu_agent extends uvm_agent;

    `uvm_component_utils(alu_agent)

    function new(string name = "alu_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    alu_driver    drv;
    alu_monitor   mon;
    uvm_sequencer #(alu_item) seqr;

    // instantiate all child components
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = alu_driver   ::type_id::create("drv",  this);
        seqr = uvm_sequencer#(alu_item)::type_id::create("seqr", this);
        mon  = alu_monitor  ::type_id::create("mon",  this);
    endfunction

    // wire the driver's TLM port to the sequencer's export,
    // and forward the monitor's analysis port upward
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass