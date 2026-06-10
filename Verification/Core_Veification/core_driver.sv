/*
* core_driver sends the instructions to the core to be executed
*
*/

class core_driver extends uvm_driver;

    //uvm factory registry
    `uvm_component_utils(core_driver);
    function new(string name = "core_driver", uvm_component parent=null);
        super.new(name, parent)
    endfunction

    //virtual interfaces for core
    virtual core_interface core_vif;
    virtual clk_interface clk_vif;

    //checks for interfces and terminates if not there
    virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual core_interface)::get(this, "", "core_interface", core_vif))
                `uvm_fatal("DRV", "No core_vif found")
            if(!uvm_config_db#(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
                `uvm_fatal("DRV", "No clk_vif found")
    endfunction

    //gets instruction from sequnece
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            rv32i_instruction_item m_core_item;
            seq_item_port.get_next_item(m_core_item);
            drive_item(m_core_item);
            seq_item_port.item_done();
        end
    endtask

    //drives instruction to core
    virtual task drive_item(alu_item m_alu_item);
        @(posedge clk_vif.tb_clk);
        core_vif.instruction <= m_core_item.alu_instruction;
    endtask
endclass