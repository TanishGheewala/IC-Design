/*
* alu_driver sends generated alu_items to alu. Using clk to
* space inputs apart. Will go through all sequence items.
*/
class alu_driver extends uvm_drver #(alu_sequence_item);

    //required UVM setup
    `uvm_component_utils(alu_driver)
    function new(string name = "alu_driver", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    //virtual interfaces
    //clk interface for testing only
    virtual alu_interfacce alu_vif;
    virtual clk_interface clk_vif;

    //checks if there is an interface to refrence for driver
    //need to add check for clk_vif
    virtual function void build_phase(uvm_phase phase):
        super.build_phase(phase);
        if(!uvm_config_db#(virtual alu_interface)::get(this, "", "alu_interface", alu_vif))
            `uvm_fatal("DRV", "No alu_vif found")
    endfunction

    //driver gets items from input sequence
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            alu_sequence_item alu_item;
            seq_item_port.get_next_item(alu_item);
            drive_item(alu_item);
            seq_item_port.item_done();
        end
    endtask

    //drives item on positve clk pulse
    virtual task drive_item(alu_sequence_item alu_item);
        @(posedge clk_vif.clk);
            alu_vif.alu_opcode <= alu_item.alu_op;
            alu_vif.in_data_0 <= alu_item.in_data_0;
            alu_vif.in_data_1 <= alu_item.in_data_1;
            alu_vif.out_data <= alu_item.out_data;
    endtask
endclass