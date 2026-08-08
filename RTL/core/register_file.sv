`timescale 1ns/1ps

module register_file(register_file_interface.rf_dut rf_if);

    logic [31:0] registers [0:31];

    always_comb begin
        if (rf_if.rs1_addr == 5'd0)
            rf_if.rs1_data = 32'd0;
        else
            rf_if.rs1_data = registers[rf_if.rs1_addr];

        if (rf_if.rs2_addr == 5'd0)
            rf_if.rs2_data = 32'd0;
        else
            rf_if.rs2_data = registers[rf_if.rs2_addr];
    end

    always_ff @(posedge rf_if.clk) begin
        if (rf_if.reg_write && (rf_if.rd_addr != 5'd0))
            registers[rf_if.rd_addr] <= rf_if.write_data;
        registers[0] <= 32'd0;
    end
endmodule