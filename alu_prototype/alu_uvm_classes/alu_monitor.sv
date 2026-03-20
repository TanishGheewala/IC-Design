/*
* alu_monitor monitors the data leaving the DUT and sends data
* to other locations, namely the scoreboard.
*/
class alu_monitor extends uvm_monitor;

    //required for uvm integration
    `uvm_component_utils(alu_monitor)
    function new(string name = "alu_monitor", uvm_component parent=null);
        super.new(name, parent);
    endfunction

    //sets up port format
    uvm_analysis_port #(alu_sequence_item) mon_analysis_port;

    //test interfaces
    virtual alu_vif;
    virtual clk_if;

    //checks interfaces are thre
    //need to add clk_vif check
    virtual function void build_phase(uvm_phase phase):
        super.build_phase(phase);
        if(!uvm_config_db#(virtual alu_interface)::get(this, "", "alu_interface", alu_vif))
            `uvm_fatal("MON", "No alu_vif found")
        mon_analysis_port = new("mon_analysis_port", this);
    endfunction

    //gets data from interface every posedge clk
    virtual task run_phase(uvm_phase phase);
        super.build_phase(phase);
        forever begin
            @(posedge clk_vif.clk)
                //creates item and stores data there
                alu_sequence_item alu_item = alu_sequence_item::type_id::create("alu_item");
                alu_item.alu_op <=  alu_vif.alu_opcode;
                alu_item.in_data_0 <= alu_vif.in_data_0;
                alu_item.in_data_1 <= alu_vif.in_data_1;
                alu_item.out_data <= alu_vif.out_data;

                //writes data to port for other classes to use
                mon_analysis_port.write(alu_item);
        end
    endtask
endclass