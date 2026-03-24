class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)

    function new(string name = "alu_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    uvm_analysis_imp #(alu_item, alu_scoreboard) ap_imp;

    function void build_phase(uvm_phase phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(alu_item data);
        bit [31:0] expected;

        // ALU expected-value logic goes here
    endfunction
endclass
