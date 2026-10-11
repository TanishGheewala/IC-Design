/*
*
* The DUT's bus port is driven directly, the
* same way io_decoder would drive it. A cycle-accurate reference model of the
* registers - CTRL, the sticky STATUS.done, and how long busy lasts - runs
* alongside the DUT:
*   - every bus read is checked against the model (RXDATA only while idle,
*     mid-frame it holds a partly shifted byte)
*   - cs_n is checked against CTRL.cs every cycle
*   - a behavioral slave model plays each frame, so the bits on mosi and the
*     byte read back from RXDATA are both checked
*
* Bit-level timing of every mode is covered by spi_shift_test; this test
* covers what the register layer adds on top. The bound spi_shift_checks SVA
* checker still watches the engine inside the master.
*/
`include "spi_master_packet.sv"
`timescale 1ns/1ps
module spi_master_test;

    localparam int FRAME_WIDTH  = 8;
    localparam int DATA_WIDTH   = 32;
    localparam int SLOT_BITS    = 6;
    localparam int CLK_DIV      = 4;
    localparam int FRAME_CYCLES = 2 * FRAME_WIDTH * CLK_DIV;
    localparam int TIMEOUT      = FRAME_CYCLES + 20;

    localparam int REG_CTRL   = 'h00;
    localparam int REG_STATUS = 'h04;
    localparam int REG_TXDATA = 'h08;
    localparam int REG_RXDATA = 'h0C;

    //interfaces
    spi_interface spi_if();
    io_interface #(.ADDR_WIDTH(SLOT_BITS), .DATA_WIDTH(DATA_WIDTH)) bus_if();

    initial spi_if.clk = 0;
    always #10 spi_if.clk = ~spi_if.clk;

    //DUT
    spi_master #(
        .FRAME_WIDTH(FRAME_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .CLK_DIV    (CLK_DIV)
    ) DUT (
        .spi_if(spi_if.spi_dut),
        .bus   (bus_if.io_dev)
    );

    spi_slave_model #(.FRAME_WIDTH(FRAME_WIDTH)) slave (
        .sclk(spi_if.sclk),
        .mosi(spi_if.mosi),
        .miso(spi_if.miso)
    );

    //attach the SVA checker to the engine inside the master
    bind spi_shift spi_shift_checks #(.FRAME_WIDTH(FRAME_WIDTH), .CLK_DIV(CLK_DIV)) u_checks (.*);

    int error_counter = 0;

    //reference model state
    logic       cpol_m, cpha_m, bit_order_m, cs_m;
    logic       done_m;
    int         busy_cnt;   //cycles left in the current frame, 0 = idle
    logic [7:0] rx_m;       //RXDATA once the current/last frame is over

    //advances the model on every clock edge from the bus signals the DUT sees
    always @(posedge spi_if.clk) begin
        if (!spi_if.rst_n) begin
            {cs_m, bit_order_m, cpha_m, cpol_m} <= '0;
            done_m   <= 1'b0;
            busy_cnt <= 0;
        end else begin
            //CTRL writes are ignored during a frame
            if (bus_if.sel && bus_if.we && bus_if.addr == REG_CTRL && busy_cnt == 0)
                {cs_m, bit_order_m, cpha_m, cpol_m} <= bus_if.wdata[3:0];

            //a TXDATA write while idle starts a frame and clears done; while busy it is ignored
            if (bus_if.sel && bus_if.we && bus_if.addr == REG_TXDATA && busy_cnt == 0) begin
                busy_cnt <= FRAME_CYCLES;
                done_m   <= 1'b0;
            end else if (busy_cnt != 0) begin
                busy_cnt <= busy_cnt - 1;
                if (busy_cnt == 1) done_m <= 1'b1;   //done shows in the same cycle busy drops
            end
        end
    end

    //Pin monitors, checked mid-cycle away from the edges:
    //  - cs_n follows CTRL.cs every cycle
    //  - while the slave is selected (cs_n low) and no frame is running, sclk
    //    must not move: the slave would take it as a clock edge. Software
    //    must change cpol only with CTRL.cs = 0.
    bit   check_pins = 1'b0;
    logic sclk_prev, cs_n_prev;
    int   busy_cnt_prev;
    always @(negedge spi_if.clk) begin
        if (check_pins) begin
            if (spi_if.cs_n !== !cs_m) begin
                error_counter++;
                $error("cs_n mismatch: expected %0b, got %0b", !cs_m, spi_if.cs_n);
            end
            if (spi_if.cs_n === 1'b0 && cs_n_prev === 1'b0 && busy_cnt == 0 && busy_cnt_prev == 0
                && spi_if.sclk !== sclk_prev) begin
                error_counter++;
                $error("sclk moved while the slave was selected and no frame was running");
            end
        end
        sclk_prev     = spi_if.sclk;
        cs_n_prev     = spi_if.cs_n;
        busy_cnt_prev = busy_cnt;
    end

    function string reg_name(int addr);
        case (addr)
            REG_CTRL:   return "CTRL";
            REG_STATUS: return "STATUS";
            REG_TXDATA: return "TXDATA";
            REG_RXDATA: return "RXDATA";
            default:    return "unmapped";
        endcase
    endfunction

    function logic [31:0] expected_rdata(int addr);
        logic [31:0] d;
        d = '0;
        case (addr)
            REG_CTRL:   d[3:0] = {cs_m, bit_order_m, cpha_m, cpol_m};
            REG_STATUS: d[1:0] = {done_m, busy_cnt != 0};
            REG_RXDATA: d[7:0] = rx_m;
            default:    ;   //TXDATA is write-only, unmapped offsets read 0
        endcase
        return d;
    endfunction

    //a byte as it appears on the wire ([7] goes first); its own inverse
    function automatic logic [7:0] wire_order(bit msb_first, logic [7:0] b);
        for (int i = 0; i < 8; i++)
            wire_order[i] = msb_first ? b[i] : b[7-i];
    endfunction

    function void check(bit ok, string what, spi_master_packet item);
        if (!ok) begin
            error_counter++;
            $error("%s", what);
            if (item != null) item.print();
        end
    endfunction

    //one bus write: held for one clock edge
    task automatic bus_write(int addr, logic [31:0] data, bit show = 1'b0);
        if (show) $display("  write %-8s 0x%08X", reg_name(addr), data);
        bus_if.sel   = 1'b1;
        bus_if.we    = 1'b1;
        bus_if.addr  = addr;
        bus_if.wdata = data;
        @(posedge spi_if.clk);
        #1;
        bus_if.sel = 1'b0;
        bus_if.we  = 1'b0;
    endtask

    //one bus read: rdata is combinational, sampled before the edge and checked
    task automatic bus_read(int addr, output logic [31:0] data, input bit show = 1'b0);
        logic [31:0] exp;
        bus_if.sel  = 1'b1;
        bus_if.we   = 1'b0;
        bus_if.addr = addr;
        #1;
        data = bus_if.rdata;
        exp  = expected_rdata(addr);
        if (!(addr == REG_RXDATA && busy_cnt != 0) && data !== exp) begin
            error_counter++;
            $error("rdata mismatch at %s: expected 0x%08X, got 0x%08X", reg_name(addr), exp, data);
        end
        if (show) $display("  read  %-8s 0x%08X", reg_name(addr), data);
        @(posedge spi_if.clk);
        #1;
        bus_if.sel = 1'b0;
    endtask

    task automatic reset_dut();
        check_pins    = 1'b0;
        spi_if.rst_n  = 1'b0;
        bus_if.sel    = 1'b0;
        bus_if.we     = 1'b0;
        bus_if.addr   = '0;
        bus_if.wdata  = '0;
        repeat (2) @(posedge spi_if.clk);
        #1;
        spi_if.rst_n = 1'b1;
        rx_m         = '0;
        check_pins   = 1'b1;
    endtask

    //CTRL value for this packet's mode with cs set
    function logic [31:0] ctrl_word(spi_master_packet item, bit cs);
        return {28'h0, cs, item.bit_order, item.cpha, item.cpol};
    endfunction

    //how software selects the slave: set the mode with cs = 0 first so sclk
    //settles at its new idle level, then assert cs
    task automatic select(spi_master_packet item, bit show = 1'b0);
        bus_write(REG_CTRL, ctrl_word(item, 1'b0), show);
        bus_write(REG_CTRL, ctrl_word(item, 1'b1), show);
    endtask

    task automatic deselect(spi_master_packet item, bit show = 1'b0);
        bus_write(REG_CTRL, ctrl_word(item, 1'b0), show);
    endtask

    //One byte through the bus with CTRL already set to the packet's mode:
    //TXDATA write, poll STATUS until busy clears, read RXDATA. With
    //item.disturb, TXDATA and CTRL are written again mid-frame (both ignored).
    task automatic transfer(spi_master_packet item, bit show);
        logic [31:0] d;
        logic [7:0]  mosi_seen;
        bit          slave_done;
        int          n;

        mosi_seen  = 'x;
        slave_done = 1'b0;

        fork
            begin
                slave.frame(item.cpol, item.cpha, item.slave_byte, mosi_seen);
                slave_done = 1'b1;
            end
        join_none

        bus_write(REG_TXDATA, {item.junk, item.tx_byte});
        rx_m = wire_order(item.bit_order, item.slave_byte);

        if (item.disturb) begin
            repeat (FRAME_CYCLES/4) @(posedge spi_if.clk);
            #1;
            bus_write(REG_TXDATA, {item.junk, ~item.tx_byte});
            bus_write(REG_CTRL, ~ctrl_word(item, 1'b1));   //cs = 0, other mode
        end

        //poll STATUS until busy clears (every read is checked against the model)
        n = 0;
        do begin
            bus_read(REG_STATUS, d);
            n++;
        end while (d[0] !== 1'b0 && n < TIMEOUT);
        check(d[0] === 1'b0, "timed out waiting for STATUS.busy to clear", item);

        bus_read(REG_RXDATA, d);
        item.rx_byte   = d[7:0];
        item.mosi_seen = mosi_seen;

        check(slave_done, "slave model did not see all sclk edges", item);
        if (!slave_done) disable fork;
        check(mosi_seen === wire_order(item.bit_order, item.tx_byte), "mosi bits wrong", item);

        if (show) begin
            $write("  ");
            item.print();
        end
    endtask

    //test begins
    initial begin
        automatic spi_master_packet item = new();
        logic [31:0] d;

        $display("[SPI_MASTER TEST START]");

        reset_dut();

        //directed cases
        $display("[CASE] reset values: CTRL, STATUS, RXDATA read 0, cs_n high, sclk low");
        bus_read(REG_CTRL,   d, 1'b1);
        bus_read(REG_STATUS, d, 1'b1);
        bus_read(REG_RXDATA, d, 1'b1);
        check(spi_if.cs_n === 1'b1, "cs_n not high after reset", null);
        check(spi_if.sclk === 1'b0, "sclk not low after reset", null);

        $display("[CASE] TXDATA is write-only and unmapped offsets read 0");
        bus_read(REG_TXDATA, d, 1'b1);
        bus_read('h10, d, 1'b1);
        bus_read('h3C, d, 1'b1);

        $display("[CASE] CTRL keeps only bits [3:0]; cpol moves sclk's idle level, cs bit drives cs_n low");
        bus_write(REG_CTRL, 32'hFFFF_FFF7, 1'b1);   //everything but cs
        bus_read(REG_CTRL, d, 1'b1);
        check(spi_if.sclk === 1'b1, "sclk not at idle level 1 with CTRL.cpol = 1", null);
        bus_write(REG_CTRL, 32'hFFFF_FFFF, 1'b1);   //now cs too
        bus_read(REG_CTRL, d, 1'b1);
        check(spi_if.cs_n === 1'b0, "cs_n not low with CTRL.cs = 1", null);
        bus_write(REG_CTRL, 32'h0000_0007, 1'b1);   //release cs before changing the mode
        bus_write(REG_CTRL, 32'h0000_0000, 1'b1);
        bus_read(REG_CTRL, d, 1'b1);
        check(spi_if.cs_n === 1'b1, "cs_n not high with CTRL.cs = 0", null);
        check(spi_if.sclk === 1'b0, "sclk not back at idle level 0", null);

        $display("[CASE] writes to STATUS, RXDATA and unmapped offsets are ignored, no frame starts");
        bus_write(REG_STATUS, 32'hFFFF_FFFF, 1'b1);
        bus_write(REG_RXDATA, 32'hFFFF_FFFF, 1'b1);
        bus_write('h10, 32'hFFFF_FFFF, 1'b1);
        bus_read(REG_CTRL,   d, 1'b1);
        bus_read(REG_STATUS, d, 1'b1);
        bus_read(REG_RXDATA, d, 1'b1);

        $display("[CASE] one byte in each mode and bit order, TXDATA 0xB4 (upper bits junk) / slave 0x1E");
        for (int m = 0; m < 8; m++) begin
            item.cpol = m[2]; item.cpha = m[1]; item.bit_order = m[0];
            item.tx_byte = 8'hB4; item.slave_byte = 8'h1E; item.junk = 24'hA5A5A5;
            item.disturb = 1'b0;
            select(item);
            transfer(item, 1'b1);
            deselect(item);
        end

        $display("[CASE] STATUS.done is sticky: survives idle cycles and RXDATA reads, cleared by the next TXDATA write");
        repeat (10) @(posedge spi_if.clk);
        #1;
        bus_read(REG_STATUS, d, 1'b1);
        bus_read(REG_RXDATA, d, 1'b1);
        bus_read(REG_STATUS, d, 1'b1);
        item.cpol = 0; item.cpha = 0; item.bit_order = 1;
        item.tx_byte = 8'h9C; item.slave_byte = 8'h37; item.disturb = 1'b0;
        select(item);
        fork
            slave.frame(item.cpol, item.cpha, item.slave_byte, item.mosi_seen);
        join_none
        bus_write(REG_TXDATA, {24'h0, item.tx_byte}, 1'b1);
        rx_m = wire_order(item.bit_order, item.slave_byte);
        bus_read(REG_STATUS, d, 1'b1);   //busy = 1, done = 0
        wait fork;
        repeat (4) @(posedge spi_if.clk);
        #1;
        bus_read(REG_STATUS, d, 1'b1);   //busy = 0, done = 1
        bus_read(REG_RXDATA, d, 1'b1);
        deselect(item);

        $display("[CASE] TXDATA and CTRL writes during a frame are ignored (cs_n stays low, frame not restarted)");
        item.cpol = 0; item.cpha = 1; item.bit_order = 1;
        item.tx_byte = 8'hC1; item.slave_byte = 8'h69; item.junk = '0; item.disturb = 1'b1;
        select(item);
        transfer(item, 1'b1);
        bus_read(REG_CTRL, d, 1'b1);
        deselect(item);
        item.cpol = 1; item.cpha = 0; item.bit_order = 0;
        item.tx_byte = 8'h83; item.slave_byte = 8'h46;
        select(item);
        transfer(item, 1'b1);
        bus_read(REG_CTRL, d, 1'b1);
        deselect(item);

        $display("[CASE] flash-style read: cs_n held low over READ 0x03, 3 address bytes, then 4 data bytes");
        item.cpol = 0; item.cpha = 0; item.bit_order = 1; item.junk = '0; item.disturb = 1'b0;
        select(item, 1'b1);
        begin
            //what the master sends / what the flash answers, byte by byte
            automatic logic [7:0] flash_tx [8] = '{8'h03, 8'h00, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
            automatic logic [7:0] flash_rx [8] = '{8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hDE, 8'hAD, 8'hBE, 8'hEF};
            for (int i = 0; i < 8; i++) begin
                item.tx_byte    = flash_tx[i];
                item.slave_byte = flash_rx[i];
                transfer(item, 1'b1);
            end
        end
        deselect(item, 1'b1);

        $display("[CASE] reset mid-frame: cs_n released, registers and RXDATA cleared");
        item.cpol = 1; item.cpha = 1; item.bit_order = 1;
        item.tx_byte = 8'hF0; item.slave_byte = 8'h0F;
        select(item);
        fork
            slave.frame(item.cpol, item.cpha, item.slave_byte, item.mosi_seen);
        join_none
        bus_write(REG_TXDATA, {24'h0, item.tx_byte});
        repeat (FRAME_CYCLES/2) @(posedge spi_if.clk);
        #1;
        spi_if.rst_n = 1'b0;
        @(posedge spi_if.clk);
        #1;
        spi_if.rst_n = 1'b1;
        rx_m = '0;
        disable fork;
        check(spi_if.cs_n === 1'b1, "cs_n not released by reset", null);
        bus_read(REG_CTRL,   d, 1'b1);
        bus_read(REG_STATUS, d, 1'b1);
        bus_read(REG_RXDATA, d, 1'b1);

        //random stimulus, one packet per byte transfer. While cs is held over
        //several bytes the mode stays the same, as it would for a real slave.
        begin
            automatic bit cs_held = 1'b0;
            automatic bit [2:0] held_mode;
            repeat (300) begin
                if (!item.randomize()) $fatal(1, "Randomization failed");
                if (cs_held) begin
                    {item.cpol, item.cpha, item.bit_order} = held_mode;
                end else begin
                    select(item);
                end
                transfer(item, 1'b0);
                if (item.release_cs) deselect(item);
                cs_held   = !item.release_cs;
                held_mode = {item.cpol, item.cpha, item.bit_order};
                repeat ($urandom_range(3)) @(posedge spi_if.clk);
                #1;
            end
        end

        //display results
        $display("[SPI_MASTER TEST COMPLETE]");
        $display("Scoreboard Errors: %0d", error_counter);
        $display("Assertion Errors:  %0d", DUT.spi_shift_inst.u_checks.fail_count);
        $display("Total Errors: %0d", error_counter + DUT.spi_shift_inst.u_checks.fail_count);
        $finish;
    end

endmodule
