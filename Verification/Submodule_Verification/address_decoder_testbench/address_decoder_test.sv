/*
* address_decoder_test is the top level testbench for the address decoder.
*
* Two DUTs are run side by side against the same stimulus: one with the I/O
* window enabled (the real MCU configuration, addr[9] splits RAM/I/O) and one
* with it disabled (the flat-RAM escape hatch used by e.g. the ISA compliance
* harness), so both configurations are checked on every cycle.
*/
`include "address_decoder_packet.sv"
`timescale 1ns/1ps
module address_decoder_test;

    localparam int ADDR_WIDTH = 10;
    localparam int IO_SEL_BIT = 9;

    //interfaces
    address_decoder_interface #(.ADDR_WIDTH(ADDR_WIDTH)) io_enabled_if();
    address_decoder_interface #(.ADDR_WIDTH(ADDR_WIDTH)) io_disabled_if();

    //DUTs
    address_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .IO_SEL_BIT(IO_SEL_BIT),
        .ENABLE_IO(1'b1)
    ) DUT_IO_ENABLED (
        .dec_if(io_enabled_if.ad_dut)
    );

    address_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .IO_SEL_BIT(IO_SEL_BIT),
        .ENABLE_IO(1'b0)
    ) DUT_IO_DISABLED (
        .dec_if(io_disabled_if.ad_dut)
    );

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results against expected output
    function bit expected_result(address_decoder_packet data, bit enable_io);
        bit error;
        bit exp_ram_sel, exp_ram_we, exp_io_sel, exp_io_we;
        bit [ADDR_WIDTH-1:0] exp_io_addr;

        if (enable_io) begin
            exp_ram_sel = ~data.addr[IO_SEL_BIT] & (data.mem_read | data.mem_write);
            exp_io_sel  =  data.addr[IO_SEL_BIT] & (data.mem_read | data.mem_write);
        end else begin
            exp_ram_sel = data.mem_read | data.mem_write;
            exp_io_sel  = 1'b0;
        end

        exp_ram_we  = exp_ram_sel & data.mem_write;
        exp_io_we   = exp_io_sel  & data.mem_write;
        exp_io_addr = data.addr & ~(1 << IO_SEL_BIT);

        error = 0;

        if (data.ram_sel !== exp_ram_sel) begin
            $error("[ENABLE_IO=%0b] ram_sel mismatch: expected %0b, got %0b", enable_io, exp_ram_sel, data.ram_sel);
            error = 1;
        end
        if (data.ram_we !== exp_ram_we) begin
            $error("[ENABLE_IO=%0b] ram_we mismatch: expected %0b, got %0b", enable_io, exp_ram_we, data.ram_we);
            error = 1;
        end
        if (data.io_sel !== exp_io_sel) begin
            $error("[ENABLE_IO=%0b] io_sel mismatch: expected %0b, got %0b", enable_io, exp_io_sel, data.io_sel);
            error = 1;
        end
        if (data.io_we !== exp_io_we) begin
            $error("[ENABLE_IO=%0b] io_we mismatch: expected %0b, got %0b", enable_io, exp_io_we, data.io_we);
            error = 1;
        end
        if (data.io_addr !== exp_io_addr) begin
            $error("[ENABLE_IO=%0b] io_addr mismatch: expected 0x%03X, got 0x%03X", enable_io, exp_io_addr, data.io_addr);
            error = 1;
        end

        if (error) data.print();

        return error;
    endfunction

    //drives the current packet's addr/mem_read/mem_write into DUT_IF, waits for
    //the combinational output to settle, and checks it against the reference
    //model. Written as a macro (rather than a task taking an interface
    //argument) since interface-typed task/function ports aren't reliably
    //supported across simulators.
    `define CHECK_ONE(DUT_IF, ENABLE_IO_FLAG) \
        DUT_IF.addr      = item.addr; \
        DUT_IF.mem_read  = item.mem_read; \
        DUT_IF.mem_write = item.mem_write; \
        #1; \
        item.ram_sel = DUT_IF.ram_sel; \
        item.ram_we  = DUT_IF.ram_we; \
        item.io_sel  = DUT_IF.io_sel; \
        item.io_we   = DUT_IF.io_we; \
        item.io_addr = DUT_IF.io_addr; \
        error_counter = error_counter + expected_result(item, ENABLE_IO_FLAG);

    //test begins
    initial begin
        automatic address_decoder_packet item = new();

        $display("[ADDRESS DECODER TEST START]");

        //directed boundary checks: last RAM word, first I/O word, and the idle
        //bus. These are the highest-risk cases (an off-by-one here would put
        //the split at the wrong address), so print them unconditionally
        //instead of only on failure - the random loop below stays quiet.
        $display("[CASE] last RAM word (0x1FC), write");
        item.addr = 10'h1FC; item.mem_read = 1'b0; item.mem_write = 1'b1;
        `CHECK_ONE(io_enabled_if, 1'b1)
        $write("  [ENABLE_IO=1] "); item.print();
        `CHECK_ONE(io_disabled_if, 1'b0)
        $write("  [ENABLE_IO=0] "); item.print();

        $display("[CASE] first I/O word (0x200), read");
        item.addr = 10'h200; item.mem_read = 1'b1; item.mem_write = 1'b0;
        `CHECK_ONE(io_enabled_if, 1'b1)
        $write("  [ENABLE_IO=1] "); item.print();
        `CHECK_ONE(io_disabled_if, 1'b0)
        $write("  [ENABLE_IO=0] "); item.print();

        $display("[CASE] first I/O word (0x200), idle bus");
        item.addr = 10'h200; item.mem_read = 1'b0; item.mem_write = 1'b0;
        `CHECK_ONE(io_enabled_if, 1'b1)
        $write("  [ENABLE_IO=1] "); item.print();
        `CHECK_ONE(io_disabled_if, 1'b0)
        $write("  [ENABLE_IO=0] "); item.print();

        //random (constrained-legal) stimulus, checked against both DUT configurations
        repeat (2000) begin
            if (!item.randomize()) $fatal(1, "Randomization failed");

            `CHECK_ONE(io_enabled_if, 1'b1)
            `CHECK_ONE(io_disabled_if, 1'b0)
        end

        //display results
        $display("[ADDRESS DECODER TEST COMPLETE]");
        $display("Total Errors: %0d", error_counter);
        $finish;
    end

endmodule
