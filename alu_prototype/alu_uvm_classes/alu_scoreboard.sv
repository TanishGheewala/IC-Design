class alu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(alu_scoreboard)

    function new(string name = "alu_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    uvm_analysis_imp #(alu_item, alu_scoreboard) ap_imp;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(alu_item data);
        bit [31:0] expected;

        case (data.alu_op)

            6'b011001: expected = data.in_data_0 + data.in_data_1;
            6'b011010: expected = data.in_data_0 - data.in_data_1;

            6'b011011: expected = data.in_data_0 & data.in_data_1;
            6'b011100: expected = data.in_data_0 | data.in_data_1;
            6'b011101: expected = data.in_data_0 ^ data.in_data_1;

            6'b011110: expected = data.in_data_0 << data.in_data_1[4:0];
            6'b011111: expected = data.in_data_0 >> data.in_data_1[4:0];
            6'b100000: expected = $signed(data.in_data_0) >>> data.in_data_1[4:0];

            6'b100001: expected = ($signed(data.in_data_0) < $signed(data.in_data_1)) ? 32'd1 : 32'd0;
            6'b100010: expected = (data.in_data_0 < data.in_data_1) ? 32'd1 : 32'd0;

            6'b100011: expected = data.in_data_0;
            6'b100100: expected = data.in_data_1;

            default: expected = 32'd0;

        endcase

        if (expected == data.out_data)
            `uvm_info("ALU_SB", "PASS", UVM_LOW)
        else
            `uvm_error("ALU_SB", "FAIL")

    endfunction

endclass
