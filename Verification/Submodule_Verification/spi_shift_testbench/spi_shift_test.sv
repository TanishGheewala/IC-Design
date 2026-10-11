/*
*
* A behavioral slave model on the pins plays its
* side of every frame by the SPI mode rules, so both directions are checked
* against an independent reference: the bits the slave saw on mosi, and the
* rx_byte the engine assembled from the slave's miso bits.
*
* The whole test runs once per CLK_DIV value: 3 (the minimum - miso goes
* through a 2-flop synchronizer), 4 (the default) and 7.
* The bound spi_shift_checks SVA checker watches every cycle of every frame
* (frame length, sclk edge count, idle level, done pulse).
*/
`include "spi_shift_packet.sv"
`timescale 1ns/1ps

module spi_shift_test;

    spi_shift_harness #(.CLK_DIV(3)) div3();
    spi_shift_harness #(.CLK_DIV(4)) div4();
    spi_shift_harness #(.CLK_DIV(7)) div7();

    //test begins
    initial begin
        int tb_errors, sva_errors;

        $display("[SPI_SHIFT TEST START]");

        div3.run_all();
        div4.run_all();
        div7.run_all();

        tb_errors  = div3.error_counter + div4.error_counter + div7.error_counter;
        sva_errors = div3.DUT.u_checks.fail_count + div4.DUT.u_checks.fail_count
                   + div7.DUT.u_checks.fail_count;

        //display results
        $display("[SPI_SHIFT TEST COMPLETE]");
        $display("Scoreboard Errors: %0d", tb_errors);
        $display("Assertion Errors:  %0d", sva_errors);
        $display("Total Errors: %0d", tb_errors + sva_errors);
        $finish;
    end

    //attach the SVA checker to every spi_shift instance
    bind spi_shift spi_shift_checks #(.FRAME_WIDTH(FRAME_WIDTH), .CLK_DIV(CLK_DIV)) u_checks (.*);

endmodule


//one complete copy of the test for a given CLK_DIV
module spi_shift_harness #(
    parameter int CLK_DIV = 4
);

    localparam int FRAME_WIDTH  = 8;
    localparam int FRAME_CYCLES = 2 * FRAME_WIDTH * CLK_DIV;  //start edge to done
    localparam int TIMEOUT      = FRAME_CYCLES + 20;

    logic       clk       = 1'b0;
    logic       rst_n     = 1'b0;
    logic       start     = 1'b0;
    logic [7:0] tx_byte   = '0;
    logic       cpol      = 1'b0;
    logic       cpha      = 1'b0;
    logic       bit_order = 1'b1;
    logic [7:0] rx_byte;
    logic       busy, done;
    logic       sclk, mosi, miso;
    logic       slave_miso;
    bit         loopback  = 1'b0;

    always #10 clk = ~clk;

    //loopback wires mosi straight back to miso for the smoke test
    assign miso = loopback ? mosi : slave_miso;

    //DUT
    spi_shift #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .CLK_DIV    (CLK_DIV)
    ) DUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .tx_byte  (tx_byte),
        .cpol     (cpol),
        .cpha     (cpha),
        .bit_order(bit_order),
        .rx_byte  (rx_byte),
        .busy     (busy),
        .done     (done),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso)
    );

    spi_slave_model #(.FRAME_WIDTH(FRAME_WIDTH)) slave (
        .sclk(sclk),
        .mosi(mosi),
        .miso(slave_miso)
    );

    
    int error_counter = 0;

    //rx_byte from the last frame; it must hold until the next start
    logic [7:0] last_rx;

    //a byte as it appears on the wire ([7] goes first). Its own inverse, so it
    //also turns wire-order bits back into the byte rx_byte should hold.
    function automatic logic [7:0] wire_order(bit msb_first, logic [7:0] b);
        for (int i = 0; i < 8; i++)
            wire_order[i] = msb_first ? b[i] : b[7-i];
    endfunction

    //acts as scoreboard for one condition
    function void check(bit ok, string what, spi_shift_packet item);
        if (!ok) begin
            error_counter++;
            $error("[CLK_DIV=%0d] %s", CLK_DIV, what);
            if (item != null) item.print();
        end
    endfunction

    task automatic reset_dut();
        rst_n = 1'b0;
        start = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        rst_n   = 1'b1;
        last_rx = '0;
    endtask

    //Plays one frame and checks it. Leaves the testbench #1 after the edge
    //that raised done.
    //  settle  = 1: config is applied a cycle ahead so sclk can move to the
    //               new idle level, and the idle state is checked.
    //  settle  = 0: start goes out in the same cycle the previous frame's done
    //               is seen (back to back); mode must match the last frame.
    //  disturb = 1: halfway through, a second start with a new byte and
    //               flipped cpha/bit_order inputs - all must be ignored.
    task automatic run_frame(spi_shift_packet item, bit show, bit settle = 1'b1, bit disturb = 1'b0);
        logic [7:0] mosi_seen;
        logic [7:0] exp_rx;
        bit         slave_done;
        int         n;

        mosi_seen  = 'x;
        slave_done = 1'b0;

        cpol      = item.cpol;
        cpha      = item.cpha;
        bit_order = item.bit_order;

        if (settle) begin
            @(posedge clk);
            #1;
            check(busy === 1'b0, "busy set while idle", item);
            check(done === 1'b0, "done set while idle", item);
            check(sclk === item.cpol, "sclk not at cpol while idle", item);
            check(rx_byte === last_rx, "rx_byte changed while idle", item);
        end

        //start pulse, slave model waiting for the first edge
        tx_byte = item.tx_byte;
        start   = 1'b1;
        fork
            begin
                slave.frame(item.cpol, item.cpha, item.slave_byte, mosi_seen);
                slave_done = 1'b1;
            end
        join_none

        @(posedge clk);
        #1;
        start = 1'b0;
        check(busy === 1'b1, "busy not set after start", item);

        //n = clock edges since the start edge
        n = 0;
        while (done !== 1'b1 && n < TIMEOUT) begin
            if (disturb && n == FRAME_CYCLES/2) begin
                start     = 1'b1;
                tx_byte   = ~item.tx_byte;
                cpha      = ~item.cpha;
                bit_order = ~item.bit_order;
            end
            @(posedge clk);
            #1;
            start = 1'b0;
            n++;
        end

        item.cycles    = n;
        item.rx_byte   = rx_byte;
        item.mosi_seen = mosi_seen;

        if (done !== 1'b1) begin
            check(1'b0, "timed out waiting for done", item);
            disable fork;
            cpha      = item.cpha;
            bit_order = item.bit_order;
            return;
        end

        check(n == FRAME_CYCLES, $sformatf("frame took %0d cycles, expected %0d", n, FRAME_CYCLES), item);
        check(busy === 1'b0, "busy still set when done", item);
        check(sclk === item.cpol, "sclk not back at cpol at end of frame", item);
        check(slave_done, "slave model did not see all sclk edges", item);
        if (!slave_done) disable fork;

        //mosi: what the slave saw, in wire order
        check(mosi_seen === wire_order(item.bit_order, item.tx_byte), "mosi bits wrong", item);

        //rx: loopback returns our own byte, otherwise the slave's bits in our bit order
        exp_rx = loopback ? item.tx_byte : wire_order(item.bit_order, item.slave_byte);
        check(rx_byte === exp_rx, $sformatf("rx_byte wrong: expected 0x%02X", exp_rx), item);

        last_rx = rx_byte;

        if (show) begin
            $write("  ");
            item.print();
        end

        //undo the disturbance only now, so the checks above prove the captured
        //cpha/bit_order were used, not the live inputs
        cpha      = item.cpha;
        bit_order = item.bit_order;
    endtask

    task automatic set_mode(spi_shift_packet item, int mode_idx);
        item.cpol      = mode_idx[2];
        item.cpha      = mode_idx[1];
        item.bit_order = mode_idx[0];
    endtask

    task automatic run_all();
        spi_shift_packet item;
        item = new();

        $display("==== CLK_DIV = %0d (%0d clk cycles per frame) ====", CLK_DIV, FRAME_CYCLES);
        reset_dut();

        $display("[CASE] reset: idle, sclk low, rx_byte 0");
        @(posedge clk);
        #1;
        check(busy === 1'b0 && done === 1'b0, "busy/done set after reset", null);
        check(sclk === 1'b0, "sclk not 0 after reset (cpol = 0)", null);
        check(rx_byte === 8'h00, "rx_byte not 0 after reset", null);

        $display("[CASE] loopback smoke test: mosi wired to miso, rx must equal tx in every mode");
        loopback = 1'b1;
        for (int m = 0; m < 8; m++) begin
            set_mode(item, m);
            item.tx_byte    = 8'hB4 + 8'(m);
            item.slave_byte = 8'h00;
            run_frame(item, 1'b1);
        end
        loopback = 1'b0;

        $display("[CASE] slave model, all 4 modes x both bit orders, tx 0xB4 / slave 0x1E");
        for (int m = 0; m < 8; m++) begin
            set_mode(item, m);
            item.tx_byte    = 8'hB4;
            item.slave_byte = 8'h1E;
            run_frame(item, 1'b1);
        end

        $display("[CASE] back to back: each next start in the cycle done is seen (modes 0 and 3, MSB first)");
        for (int m = 1; m < 8; m += 6) begin  //mode index 1 = mode 0 MSB, 7 = mode 3 MSB
            set_mode(item, m);
            item.tx_byte = 8'h03; item.slave_byte = 8'hC5;
            run_frame(item, 1'b1, 1'b1);
            item.tx_byte = 8'h12; item.slave_byte = 8'h5C;
            run_frame(item, 1'b1, 1'b0);
            item.tx_byte = 8'h34; item.slave_byte = 8'hA0;
            run_frame(item, 1'b1, 1'b0);
            item.tx_byte = 8'h56; item.slave_byte = 8'h0A;
            run_frame(item, 1'b1, 1'b0);
        end

        $display("[CASE] start, new byte and flipped cpha/bit_order during a frame are ignored");
        set_mode(item, 3);  //mode 1, MSB first
        item.tx_byte = 8'hC1; item.slave_byte = 8'h69;
        run_frame(item, 1'b1, 1'b1, 1'b1);
        set_mode(item, 4);  //mode 2, LSB first
        item.tx_byte = 8'h83; item.slave_byte = 8'h46;
        run_frame(item, 1'b1, 1'b1, 1'b1);

        $display("[CASE] reset mid-frame: busy drops at once, sclk returns to cpol, next frame is clean");
        set_mode(item, 7);  //mode 3, MSB first
        cpol = 1'b1; cpha = 1'b1; bit_order = 1'b1;
        @(posedge clk);
        #1;
        tx_byte = 8'hF0;
        start   = 1'b1;
        @(posedge clk);
        #1;
        start = 1'b0;
        repeat (FRAME_CYCLES/2) @(posedge clk);
        #1;
        check(busy === 1'b1, "not busy halfway through the frame", null);
        rst_n = 1'b0;
        @(posedge clk);
        #1;
        check(busy === 1'b0 && done === 1'b0, "busy/done not cleared by reset", null);
        check(rx_byte === 8'h00, "rx_byte not cleared by reset", null);
        rst_n   = 1'b1;
        last_rx = '0;
        @(posedge clk);
        #1;
        check(sclk === 1'b1, "sclk not back at cpol after reset", null);
        check(done === 1'b0, "done pulsed after a reset-aborted frame", null);
        item.tx_byte = 8'h5A; item.slave_byte = 8'hE7;
        run_frame(item, 1'b1);

        //random stimulus, one packet per frame
        repeat (300) begin
            if (!item.randomize()) $fatal(1, "Randomization failed");
            run_frame(item, 1'b0, 1'b1, ($urandom_range(9) == 0));
        end
    endtask

endmodule
