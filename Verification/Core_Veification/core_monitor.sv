/*
* core_monitor monitors the data leaving the core DUT
*/

class core_monitor extends uvm_monitor;

    //uvm facory setup
    `uvm_component_utils(core_monitor)
    function new(string name = "core_monitor", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    //sets up port format
    uvm_analysis_port #(core_state_item) mon_analysis_port;

    //need to add binds to "probe" into submodulees to get CPU state
    //virtual interfaces for core state
    virtual clk_interface clk_vif;
    //reg interface
    //program counter interface
    //internal signal

    //checks interfaces are there
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual core_interface)::get(this, "", "core_interface", core_vif))
            `uvm_fatal("MON", "No core_vif found")
        if(!uvm_config_db#(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
            `uvm_fatal("DRV", "No clk_vif found")
        mon_analysis_port = new("mon_analysis_port", this);
    endfunction

    //gets data from interface every posedge clk
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            rv32i_instrucion_item m_core_item = alu_item::type_id::create("m_core_item");
        #1;
            @(clk_vif.tb_clk);
            //need to create item for CPU state that contains info on registers, memory, ect.
            //item.reg <= reg
            //item.pc <= pc
            //item.next_pc <= next_pc
            mon_analysis_port.write(m_core_item);
        end
    endtask
endclass