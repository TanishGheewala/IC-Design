`include "register_file_packet.sv"
`timescale 1ns/1ps

module register_file_tb;

    register_file_interface rf_if();
    register_file DUT (
        .rf_if(rf_if.rf_dut)
    );

    initial rf_if.clk = 0;
    always #5 rf_if.clk = ~rf_if.clk;

    bit [31:0] expected_registers [0:31];

    int error_counter = 0;

    function bit expected_result(register_file_packet data);
        bit error;
        bit [31:0] expected_rs1_data;
        bit [31:0] expected_rs2_data;

        expected_rs1_data = expected_registers[data.rs1_addr];
        expected_rs2_data = expected_registers[data.rs2_addr];
        error = 0;

        if (data.rs1_data !== expected_rs1_data) begin
            $error("rs1_data mismatch: expected %0h, got %0h",
                   expected_rs1_data, data.rs1_data);
            error = 1;
        end

        if (data.rs2_data !== expected_rs2_data) begin
            $error("rs2_data mismatch: expected %0h, got %0h",
                   expected_rs2_data, data.rs2_data);
            error = 1;
        end

        if (error) data.print();

        return error;
    endfunction

    initial begin
        register_file_packet register_file_item = new();

        $display("[REGISTER FILE TEST START]");

        rf_if.rs1_addr  = 5'd0;
        rf_if.rs2_addr  = 5'd0;
        rf_if.rd_addr   = 5'd0;
        rf_if.write_data = 32'd0;
        rf_if.reg_write = 1'b0;

        for (int i = 1; i < 32; i++) begin
            rf_if.rd_addr    = i;
            rf_if.write_data = 32'h1000_0000 + i;
            rf_if.reg_write  = 1'b1;

            @(posedge rf_if.clk);
            #1;

            expected_registers[i] = 32'h1000_0000 + i;
        end

        rf_if.rs1_addr   = 5'd0;
        rf_if.rs2_addr   = 5'd0;
        rf_if.rd_addr    = 5'd0;
        rf_if.write_data = 32'hDEAD_BEEF;
        rf_if.reg_write  = 1'b1;

        @(posedge rf_if.clk);
        #1;

        expected_registers[0] = 32'd0;

        if ((rf_if.rs1_data !== 32'd0) || (rf_if.rs2_data !== 32'd0)) begin
            $error("x0 did not remain zero");
            error_counter++;
        end

        rf_if.reg_write = 1'b0;

        repeat(1000) begin
            if (!register_file_item.randomize())
                $fatal(1, "Randomization failed");

            rf_if.rs1_addr   = register_file_item.rs1_addr;
            rf_if.rs2_addr   = register_file_item.rs2_addr;
            rf_if.rd_addr    = register_file_item.rd_addr;
            rf_if.write_data = register_file_item.write_data;
            rf_if.reg_write  = register_file_item.reg_write;

            #1;

            register_file_item.rs1_data = rf_if.rs1_data;
            register_file_item.rs2_data = rf_if.rs2_data;

            error_counter = error_counter + expected_result(register_file_item);

            @(posedge rf_if.clk);
            #1;

            if (register_file_item.reg_write &&
                (register_file_item.rd_addr != 5'd0))
                expected_registers[register_file_item.rd_addr] =
                    register_file_item.write_data;

            expected_registers[0] = 32'd0;
        end

        rf_if.reg_write = 1'b0;

        for (int i = 0; i < 32; i++) begin
            rf_if.rs1_addr = i;
            rf_if.rs2_addr = i;
            #1;

            if ((rf_if.rs1_data !== expected_registers[i]) ||
                (rf_if.rs2_data !== expected_registers[i])) begin
                $error("Final register check failed for x%0d", i);
                error_counter++;
            end
        end
        $display("[REGISTER FILE TEST COMPLETE]");
        $display("Total Errors: %0d", error_counter);
        $finish;
    end

endmodule