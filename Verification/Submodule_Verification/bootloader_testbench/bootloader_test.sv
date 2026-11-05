/*
* bootloader_test boots the bootloader into the real instruction SRAM, with spi_slave_model playing the flash.
*
* What is checked:
*   - flash side: the bootloader sends READ 0x03 and FLASH_BASE_ADDR, cs_n
*     falls exactly once per boot, after the power-up wait, and the flash
*     sees exactly 4 + IMAGE_BYTES frames
*   - every SRAM write as it happens: address counts up by one, the byte
*     mask has only the lane for that address, and the data in that lane is
*     the flash byte. No writes once boot_done is high.
*   - final contents: after boot_done every word is read back through the
*     SRAM's read port and compared to expected_word(), including the
*     partial last word and the word after the image (both must keep their
*     unwritten lanes X)
*   - pins: cs_n high and sclk still while the flash is deselected
*
* IMAGE_BYTES = 2063 crosses the 2 KB bank boundary (bank 0 -> bank 1) and
* ends on a partial word. The clock is 80 MHz, the MCU target.
* The bound spi_shift_checks SVA checker watches the engine inside the bootloader.
*/
`include "bootloader_unit_packet.sv"
`timescale 1ns/1ps
module bootloader_test;

    localparam int          FRAME_WIDTH     = 8;
    localparam int          DATA_WIDTH      = 32;
    localparam int          ADDR_WIDTH      = 13;
    localparam int          CLK_DIV         = 4;
    localparam int          IMAGE_BYTES     = 2063;
    localparam logic [23:0] FLASH_BASE_ADDR = 24'hA5_1F03;
    localparam int          POWERUP_CYCLES  = 50;
    localparam int          FRAME_CYCLES    = 2 * FRAME_WIDTH * CLK_DIV;
    localparam int          TIMEOUT         = POWERUP_CYCLES + (4 + IMAGE_BYTES) * (FRAME_CYCLES + 4) + 100;
    localparam int          RANDOM_BOOTS    = 3;


    spi_interface spi_if();

    initial spi_if.clk = 0;
    always #6.25 spi_if.clk = ~spi_if.clk;   //80 MHz

    //bootloader -> SRAM write port
    logic                  mem_we;
    logic [DATA_WIDTH-1:0] mem_wdata;
    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [3:0]            mem_wmask;
    logic                  boot_done;

    //SRAM address: bootloader while booting, testbench readback after,
    //the same mux soc.sv will use in the core
    logic [ADDR_WIDTH-1:0] tb_addr;
    logic [ADDR_WIDTH-1:0] sram_addr;
    logic [DATA_WIDTH-1:0] sram_rdata;
    assign sram_addr = boot_done ? tb_addr : mem_addr;

    bootloader #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .FRAME_WIDTH    (FRAME_WIDTH),
        .CLK_DIV        (CLK_DIV),
        .IMAGE_BYTES    (IMAGE_BYTES),
        .FLASH_BASE_ADDR(FLASH_BASE_ADDR),
        .POWERUP_CYCLES (POWERUP_CYCLES)
    ) DUT (
        .spi_if   (spi_if.spi_dut),
        .mem_we   (mem_we),
        .mem_wdata(mem_wdata),
        .mem_addr (mem_addr),
        .mem_wmask(mem_wmask),
        .boot_done(boot_done)
    );

    //instruction memory
    instruction_memory_sram6k #(.ADDR_WIDTH(ADDR_WIDTH)) SRAM (
        .clk     (spi_if.clk),
        .we      (mem_we),
        .wmask   (mem_wmask),
        .addr    (sram_addr),
        .data_in (mem_wdata),
        .data_out(sram_rdata)
    );

    //flash slave model
    spi_slave_model #(.FRAME_WIDTH(FRAME_WIDTH)) flash (
        .sclk(spi_if.sclk),
        .mosi(spi_if.mosi),
        .miso(spi_if.miso)
    );

    //attach the SVA checker to the engine inside the bootloader
    bind spi_shift spi_shift_checks #(.FRAME_WIDTH(FRAME_WIDTH), .CLK_DIV(CLK_DIV)) u_checks (.*);

    int error_counter = 0;

    bootloader_packet item;   //boot in progress, read by the flash model and the monitors

    function void check(bit ok, string what);
        if (!ok) begin
            error_counter++;
            $error("%s", what);
        end
    endfunction

    //per-boot counters, cleared by start_boot()
    int expected_idx; //next image byte the bootloader should write
    int write_count; //mem_we pulses seen
    int flash_frames; //complete byte frames the flash saw
    int cs_falls; //cs_n falling edges
    int powerup_seen; //cycles cs_n stayed high after reset release

    //Flash model: one transaction per cs_n low. The first 4 frames are the
    //command and address (recorded into the packet, flash answers 0xFF);
    //after that it streams flash_byte() from the address it was given.
    //The transaction ends when cs_n rises, which also aborts the frame
    //that was waiting for the next sclk edge.
    task automatic flash_transaction();
        @(negedge spi_if.cs_n);
        fork
            begin
                logic [7:0] miso_b, mosi_b;
                for (int k = 0; ; k++) begin
                    miso_b = (k < 4) ? 8'hFF : item.flash_byte(item.addr_seen + 24'(k - 4));
                    flash.frame(1'b0, 1'b0, miso_b, mosi_b);   //mode 0, MSB first
                    if (k == 0)
                        item.cmd_seen = mosi_b;
                    else if (k < 4)
                        item.addr_seen = {item.addr_seen[15:0], mosi_b};
                    flash_frames++;
                end
            end
            @(posedge spi_if.cs_n);
        join_any
        disable fork;
    endtask

    initial forever flash_transaction();

    //Write scoreboard, sampled mid-cycle, the SRAM captures these on the next posedge
    bit check_pins = 1'b0;
    always @(negedge spi_if.clk) begin
        if (check_pins && mem_we === 1'b1) begin
            automatic int lane = expected_idx % 4;
            write_count++;
            check(!boot_done, "SRAM write after boot_done");
            if (expected_idx >= IMAGE_BYTES) begin
                check(1'b0, $sformatf("SRAM write past the image (byte %0d)", expected_idx));
            end else begin
                check(mem_addr === ADDR_WIDTH'(expected_idx),
                      $sformatf("write address: expected 0x%04X, got 0x%04X", expected_idx, mem_addr));
                check(mem_wmask === (4'b0001 << lane),
                      $sformatf("byte %0d: wmask expected %04b, got %04b", expected_idx, 4'b0001 << lane, mem_wmask));
                check(mem_wdata[8*lane +: 8] === item.image[expected_idx],
                      $sformatf("byte %0d: data expected 0x%02X, got 0x%02X",
                                expected_idx, item.image[expected_idx], mem_wdata[8*lane +: 8]));
            end
            expected_idx++;
        end
    end

    //Pin monitor:
    //  - cs_n falling edges are counted; the first one must come after the power-up wait
    //  - while cs_n is high (flash deselected) sclk must not move
    //  - once boot_done is high cs_n must be high
    logic sclk_prev, cs_n_prev;
    always @(negedge spi_if.clk) begin
        if (check_pins) begin
            if (cs_falls == 0 && spi_if.cs_n === 1'b1)
                powerup_seen++;
            if (cs_n_prev === 1'b1 && spi_if.cs_n === 1'b0) begin
                cs_falls++;
                check(cs_falls > 1 || powerup_seen >= POWERUP_CYCLES,
                      $sformatf("cs_n fell after %0d cycles, power-up wait is %0d", powerup_seen, POWERUP_CYCLES));
            end
            check(!(spi_if.cs_n === 1'b1 && cs_n_prev === 1'b1 && spi_if.sclk !== sclk_prev),
                  "sclk moved while cs_n was high");
            check(!(boot_done === 1'b1 && spi_if.cs_n !== 1'b1), "cs_n low after boot_done");
        end
        sclk_prev = spi_if.sclk;
        cs_n_prev = spi_if.cs_n;
    end

    //reset, clear the per-boot counters, release reset: the boot starts
    task automatic start_boot(bootloader_packet p);
        check_pins   = 1'b0;
        item         = p;
        item.cmd_seen  = 'x;
        item.addr_seen = 'x;
        spi_if.rst_n = 1'b0;
        tb_addr      = '0;
        repeat (3) @(posedge spi_if.clk);
        #1;
        check(spi_if.cs_n === 1'b1, "cs_n not high during reset");
        check(boot_done === 1'b0, "boot_done not cleared by reset");
        expected_idx = 0;
        write_count  = 0;
        flash_frames = 0;
        cs_falls     = 0;
        powerup_seen = 0;
        spi_if.rst_n = 1'b1;
        check_pins   = 1'b1;
    endtask

    //one word through the SRAM's read port: address captured on a posedge,
    //data out after the following negedge (+ the macro's 3 ns delay)
    task automatic read_sram_word(int w, output logic [31:0] data);
        tb_addr = ADDR_WIDTH'(4 * w);
        @(posedge spi_if.clk);
        @(negedge spi_if.clk);
        #4;
        data = sram_rdata;
    endtask

    //wait for boot_done, check the flash side, then read back and compare the SRAM
    task automatic finish_boot(bootloader_packet p, bit show);
        int mismatches = 0;
        bit timed_out  = 1'b0;

        fork
            wait (boot_done === 1'b1);
            begin
                repeat (TIMEOUT) @(posedge spi_if.clk);
                timed_out = 1'b1;
            end
        join_any
        disable fork;
        check(!timed_out, "timed out waiting for boot_done");

        //a few idle cycles: nothing may move after boot_done
        repeat (10) @(posedge spi_if.clk);
        #1;

        p.write_count = write_count;
        check(p.cmd_seen === 8'h03, $sformatf("command: expected 0x03, got 0x%02X", p.cmd_seen));
        check(p.addr_seen === FLASH_BASE_ADDR,
              $sformatf("flash address: expected 0x%06X, got 0x%06X", FLASH_BASE_ADDR, p.addr_seen));
        check(cs_falls == 1, $sformatf("cs_n fell %0d times, expected once", cs_falls));
        check(flash_frames == 4 + IMAGE_BYTES,
              $sformatf("flash saw %0d frames, expected %0d", flash_frames, 4 + IMAGE_BYTES));
        check(write_count == IMAGE_BYTES,
              $sformatf("%0d SRAM writes, expected %0d", write_count, IMAGE_BYTES));

        //readback, including one word past the image
        p.sram_words = new[p.n_words() + 1];
        foreach (p.sram_words[w]) begin
            read_sram_word(w, p.sram_words[w]);
            if (p.sram_words[w] !== p.expected_word(w)) begin
                mismatches++;
                if (mismatches <= 10)
                    $error("SRAM word %0d (addr 0x%04X): expected 0x%08X, got 0x%08X",
                           w, 4*w, p.expected_word(w), p.sram_words[w]);
            end
        end
        if (mismatches > 0) begin
            error_counter += mismatches;
            $display("  %0d SRAM words wrong", mismatches);
        end

        if (show || mismatches > 0) begin
            $write("  ");
            p.print();
        end
    endtask

    //test begins
    initial begin
        automatic bootloader_packet p;

        $display("[BOOTLOADER TEST START]");
        $display("  %0d bytes from flash 0x%06X, CLK_DIV %0d, power-up wait %0d cycles",
                 IMAGE_BYTES, FLASH_BASE_ADDR, CLK_DIV, POWERUP_CYCLES);

        //directed: readable pattern, byte i = i*37+11
        $display("[CASE] directed boot, index pattern: command, address, every write and full SRAM readback");
        p = new(IMAGE_BYTES, FLASH_BASE_ADDR);
        p.fill_index_pattern();
        start_boot(p);
        finish_boot(p, 1'b1);
        $display("  word 511 (last in bank 0): 0x%08X, word 512 (first in bank 1): 0x%08X, last word %0d: 0x%08X",
                 p.sram_words[511], p.sram_words[512], p.n_words()-1, p.sram_words[p.n_words()-1]);

        //random images, one packet per boot. Each boot overwrites the last one,
        //so a byte the bootloader skipped would still hold the old image.
        $display("[CASE] %0d random boots, reset between each", RANDOM_BOOTS);
        repeat (RANDOM_BOOTS) begin
            p = new(IMAGE_BYTES, FLASH_BASE_ADDR);
            if (!p.randomize()) $fatal(1, "Randomization failed");
            start_boot(p);
            finish_boot(p, 1'b1);
        end

        $display("[CASE] reset mid-boot: cs_n released at once, next boot starts over and copies everything");
        p = new(IMAGE_BYTES, FLASH_BASE_ADDR);
        if (!p.randomize()) $fatal(1, "Randomization failed");
        start_boot(p);
        wait (write_count == IMAGE_BYTES / 2);
        @(posedge spi_if.clk);
        #1;
        check_pins   = 1'b0;
        spi_if.rst_n = 1'b0;
        @(posedge spi_if.clk);
        #1;
        check(spi_if.cs_n === 1'b1, "cs_n not released by reset mid-boot");
        check(boot_done === 1'b0, "boot_done set by an aborted boot");
        $display("  reset after %0d of %0d bytes", write_count, IMAGE_BYTES);
        p = new(IMAGE_BYTES, FLASH_BASE_ADDR);
        if (!p.randomize()) $fatal(1, "Randomization failed");
        start_boot(p);
        finish_boot(p, 1'b1);

        //display results
        $display("[BOOTLOADER TEST COMPLETE]");
        $display("Scoreboard Errors: %0d", error_counter);
        $display("Assertion Errors:  %0d", DUT.spi_shift_inst.u_checks.fail_count);
        $display("Total Errors: %0d", error_counter + DUT.spi_shift_inst.u_checks.fail_count);
        $finish;
    end

endmodule
