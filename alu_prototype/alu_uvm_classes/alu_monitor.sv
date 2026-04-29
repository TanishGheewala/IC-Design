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
    uvm_analysis_port #(alu_item) mon_analysis_port;

    //test interfaces
    virtual alu_interface alu_vif;
    virtual clk_interface clk_vif;

    //checks interfaces are thre
    //need to add clk_vif check
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual alu_interface)::get(this, "", "alu_interface", alu_vif))
            `uvm_fatal("MON", "No alu_vif found")
        if(!uvm_config_db#(virtual clk_interface)::get(this, "", "clk_interface", clk_vif))
            `uvm_fatal("DRV", "No clk_vif found")
        mon_analysis_port = new("mon_analysis_port", this);
    endfunction

    //gets data from interface every posedge clk
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        //updates when clk updates -- changed from on any input
        forever begin
            alu_item m_alu_item = alu_item::type_id::create("m_alu_item");
            #1;
                @(clk_vif.tb_clk);
                //creates item and stores data there
                m_alu_item.alu_op =  alu_vif.alu_opcode;
                m_alu_item.in_data_0 = alu_vif.in_data_0;
                m_alu_item.in_data_1 = alu_vif.in_data_1;
                m_alu_item.out_data = alu_vif.out_data;

            //writes data to port for other classes to use
            mon_analysis_port.write(m_alu_item);
        end
    endtask
endclass