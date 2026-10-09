/*
* gpio_test is the top level testbench for the GPIO peripheral.
*
* The DUT's bus port is driven directly (no io_decoder in front of it), the
* same way io_decoder would drive it from slot 0. A cycle-accurate reference
* model of the DIR/OUT registers and the 2-flop input synchronizer runs
* alongside the DUT, and every cycle the DUT's read data and pin outputs are
* checked against it.
*
* Each cycle: inputs change just after a clock edge (as the core's would),
* combinational outputs are checked before the next edge, then the model is
* advanced by that edge.
*/
`include "gpio_packet.sv"
`timescale 1ns/1ps
module gpio_test;

    localparam int GPIO_WIDTH = 10;
    localparam int DATA_WIDTH = 32;
    localparam int SLOT_BITS  = 6;

    localparam int REG_DIR = 'h00;
    localparam int REG_OUT = 'h04;
    localparam int REG_IN  = 'h08;

    //interfaces
    gpio_interface #(.GPIO_WIDTH(GPIO_WIDTH)) gpio_if();
    io_interface #(.ADDR_WIDTH(SLOT_BITS), .DATA_WIDTH(DATA_WIDTH)) bus_if();

    initial gpio_if.clk = 0;
    always #10 gpio_if.clk = ~gpio_if.clk;

    //DUT
    gpio #(
        .GPIO_WIDTH(GPIO_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .gpio_if(gpio_if.gpio_dut),
        .bus(bus_if.io_dev)
    );

    //reference model state
    logic [GPIO_WIDTH-1:0] dir_m;
    logic [GPIO_WIDTH-1:0] out_m;
    logic [GPIO_WIDTH-1:0] meta_m;
    logic [GPIO_WIDTH-1:0] sync_m;

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results against expected output. rdata is
    //only checked on selected cycles - that's the only time io_decoder
    //forwards it to the core.
    function bit expected_result(gpio_packet data);
        bit error;
        logic [DATA_WIDTH-1:0] exp_rdata;

        exp_rdata = '0;
        if      (data.addr == REG_DIR) exp_rdata[GPIO_WIDTH-1:0] = dir_m;
        else if (data.addr == REG_OUT) exp_rdata[GPIO_WIDTH-1:0] = out_m;
        else if (data.addr == REG_IN)  exp_rdata[GPIO_WIDTH-1:0] = sync_m;

        error = 0;

        if (data.sel && data.rdata !== exp_rdata) begin
            $error("rdata mismatch at %s: expected 0x%08X, got 0x%08X", data.reg_name(), exp_rdata, data.rdata);
            error = 1;
        end
        if (data.gpio_oe !== dir_m) begin
            $error("gpio_oe mismatch: expected 0x%03X, got 0x%03X", dir_m, data.gpio_oe);
            error = 1;
        end
        if (data.gpio_out !== out_m) begin
            $error("gpio_out mismatch: expected 0x%03X, got 0x%03X", out_m, data.gpio_out);
            error = 1;
        end

        if (error) data.print();

        return error;
    endfunction

    //advances the reference model by one clock edge using this cycle's inputs
    function void model_update(gpio_packet data);
        if (!data.rst_n) begin
            dir_m  = '0;
            out_m  = '0;
            meta_m = '0;
            sync_m = '0;
        end else begin
            if (data.sel && data.we) begin
                if      (data.addr == REG_DIR) dir_m = data.wdata[GPIO_WIDTH-1:0];
                else if (data.addr == REG_OUT) out_m = data.wdata[GPIO_WIDTH-1:0];
            end
            sync_m = meta_m;
            meta_m = data.gpio_in;
        end
    endfunction

    //applies one packet for one clock cycle. check = 0 is only used for the
    //initial reset, before the model and DUT share a known state.
    task automatic run_cycle(gpio_packet item, bit check, bit show);
        gpio_if.rst_n   = item.rst_n;
        gpio_if.gpio_in = item.gpio_in;
        bus_if.addr     = item.addr;
        bus_if.sel      = item.sel;
        bus_if.we       = item.we;
        bus_if.wdata    = item.wdata;
        #1;
        item.rdata    = bus_if.rdata;
        item.gpio_out = gpio_if.gpio_out;
        item.gpio_oe  = gpio_if.gpio_oe;
        if (check) error_counter = error_counter + expected_result(item);
        if (show) begin
            $write("  ");
            item.print();
        end
        @(posedge gpio_if.clk);
        model_update(item);
        #1;
    endtask

    //one bus access as a directed, printed cycle
    task automatic access(gpio_packet item, int addr, bit we, logic [31:0] wdata);
        item.rst_n = 1'b1;
        item.addr  = addr;
        item.sel   = 1'b1;
        item.we    = we;
        item.wdata = wdata;
        run_cycle(item, 1'b1, 1'b1);
    endtask

    //test begins
    initial begin
        automatic gpio_packet item = new();

        $display("[GPIO TEST START]");

        //initial reset: two cycles, unchecked, brings DUT and model to the same state
        item.rst_n = 1'b0; item.sel = 1'b0; item.we = 1'b0;
        item.addr = '0; item.wdata = '0; item.gpio_in = 10'h2A5;
        run_cycle(item, 1'b0, 1'b0);
        run_cycle(item, 1'b0, 1'b0);

        //directed cases, printed. The scoreboard checks every one of them too.
        $display("[CASE] reset values: DIR and OUT read 0, no pin driven");
        access(item, REG_DIR, 1'b0, '0);
        access(item, REG_OUT, 1'b0, '0);

        $display("[CASE] DIR write keeps only the low 10 bits");
        access(item, REG_DIR, 1'b1, 32'hFFFF_F0F0);
        access(item, REG_DIR, 1'b0, '0);

        $display("[CASE] OUT write drives gpio_out");
        access(item, REG_OUT, 1'b1, 32'h0000_0333);
        access(item, REG_OUT, 1'b0, '0);

        $display("[CASE] IN is read-only, write ignored");
        access(item, REG_IN, 1'b1, 32'hFFFF_FFFF);
        access(item, REG_IN, 1'b0, '0);

        $display("[CASE] unmapped offset 0x0C: write ignored, reads 0");
        access(item, 'h0C, 1'b1, 32'hFFFF_FFFF);
        access(item, 'h0C, 1'b0, '0);

        $display("[CASE] synchronizer latency: pins change 0x2A5 -> 0x15A, IN follows two edges later");
        item.gpio_in = 10'h15A;
        access(item, REG_IN, 1'b0, '0);
        access(item, REG_IN, 1'b0, '0);
        access(item, REG_IN, 1'b0, '0);

        $display("[CASE] reset mid-run clears DIR and OUT");
        item.rst_n = 1'b0; item.sel = 1'b0; item.we = 1'b0;
        run_cycle(item, 1'b1, 1'b1);
        access(item, REG_DIR, 1'b0, '0);
        access(item, REG_OUT, 1'b0, '0);

        //random (constrained-legal) stimulus, one packet per clock cycle
        repeat (2000) begin
            if (!item.randomize()) $fatal(1, "Randomization failed");
            run_cycle(item, 1'b1, 1'b0);
        end

        //display results
        $display("[GPIO TEST COMPLETE]");
        $display("Total Errors: %0d", error_counter);
        $finish;
    end

endmodule
