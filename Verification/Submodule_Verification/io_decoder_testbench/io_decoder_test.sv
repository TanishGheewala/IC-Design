/*
* io_decoder_test is the top level testbench for the I/O window sub-decoder.
*
* Two DUTs are run side by side against the same stimulus:
*   CFG_A - the default build: 64 B slots, 4 peripherals, slots 4-7 unmapped
*   CFG_B - 32 B slots with all 16 slots populated, so the window is full and
*           there is no unmapped region
* Each peripheral slot is modeled by driving a per-packet random value onto
* its rdata, so the read mux is checked against a known answer every cycle.
*/
`include "io_decoder_packet.sv"
`timescale 1ns/1ps
module io_decoder_test;

    localparam int ADDR_WIDTH = 10;
    localparam int DATA_WIDTH = 32;
    localparam int IO_SEL_BIT = ADDR_WIDTH - 1;

    localparam int A_SLOT_BITS = 6;
    localparam int A_NUM       = 4;
    localparam int B_SLOT_BITS = 5;
    localparam int B_NUM       = 16;

    //interfaces
    io_decoder_interface #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) a_if();
    io_decoder_interface #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) b_if();

    io_interface #(.ADDR_WIDTH(A_SLOT_BITS), .DATA_WIDTH(DATA_WIDTH)) a_periph_if [A_NUM] ();
    io_interface #(.ADDR_WIDTH(B_SLOT_BITS), .DATA_WIDTH(DATA_WIDTH)) b_periph_if [B_NUM] ();

    //DUTs
    io_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLOT_BITS(A_SLOT_BITS),
        .NUM_PERIPHS(A_NUM)
    ) DUT_CFG_A (
        .dec_if(a_if.iod_dut),
        .periph_if(a_periph_if)
    );

    io_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .SLOT_BITS(B_SLOT_BITS),
        .NUM_PERIPHS(B_NUM)
    ) DUT_CFG_B (
        .dec_if(b_if.iod_dut),
        .periph_if(b_periph_if)
    );

    //peripheral models and output taps. Interface arrays can only be indexed
    //by constants, so each slot's signals are mirrored into plain arrays that
    //the procedural code below can loop over.
    logic [DATA_WIDTH-1:0]  a_rdata_drv [A_NUM];
    logic                   a_sel       [A_NUM];
    logic                   a_we        [A_NUM];
    logic [A_SLOT_BITS-1:0] a_addr      [A_NUM];
    logic [DATA_WIDTH-1:0]  a_wdata     [A_NUM];

    logic [DATA_WIDTH-1:0]  b_rdata_drv [B_NUM];
    logic                   b_sel       [B_NUM];
    logic                   b_we        [B_NUM];
    logic [B_SLOT_BITS-1:0] b_addr      [B_NUM];
    logic [DATA_WIDTH-1:0]  b_wdata     [B_NUM];

    for (genvar i = 0; i < A_NUM; i++) begin : g_a_periph
        assign a_periph_if[i].rdata = a_rdata_drv[i];
        assign a_sel[i]   = a_periph_if[i].sel;
        assign a_we[i]    = a_periph_if[i].we;
        assign a_addr[i]  = a_periph_if[i].addr;
        assign a_wdata[i] = a_periph_if[i].wdata;
    end

    for (genvar i = 0; i < B_NUM; i++) begin : g_b_periph
        assign b_periph_if[i].rdata = b_rdata_drv[i];
        assign b_sel[i]   = b_periph_if[i].sel;
        assign b_we[i]    = b_periph_if[i].we;
        assign b_addr[i]  = b_periph_if[i].addr;
        assign b_wdata[i] = b_periph_if[i].wdata;
    end

    //error counting variable
    int error_counter = 0;

    //acts as scoreboard, checks results against expected output. The slot is
    //computed by shift/mask rather than the DUT's bit-slice so the two don't
    //share a mistake.
    function bit expected_result(io_decoder_packet data, int slot_bits, int num_periphs);
        bit error;
        int slot;
        bit [ADDR_WIDTH-1:0] exp_local;
        bit [DATA_WIDTH-1:0] exp_rdata;
        bit exp_sel, exp_we;

        slot      = (data.io_addr & ((1 << IO_SEL_BIT) - 1)) >> slot_bits;
        exp_local = data.io_addr & ((1 << slot_bits) - 1);
        exp_rdata = (data.io_sel && slot < num_periphs) ? data.periph_rdata[slot] : '0;

        error = 0;

        for (int k = 0; k < num_periphs; k++) begin
            exp_sel = data.io_sel && (slot == k);
            exp_we  = data.io_we  && (slot == k);

            if (data.sel[k] !== exp_sel) begin
                $error("[SLOT_BITS=%0d] slot %0d sel mismatch: expected %0b, got %0b", slot_bits, k, exp_sel, data.sel[k]);
                error = 1;
            end
            if (data.we[k] !== exp_we) begin
                $error("[SLOT_BITS=%0d] slot %0d we mismatch: expected %0b, got %0b", slot_bits, k, exp_we, data.we[k]);
                error = 1;
            end
            if (data.addr[k] !== exp_local) begin
                $error("[SLOT_BITS=%0d] slot %0d addr mismatch: expected 0x%02X, got 0x%02X", slot_bits, k, exp_local, data.addr[k]);
                error = 1;
            end
            if (data.p_wdata[k] !== data.wdata) begin
                $error("[SLOT_BITS=%0d] slot %0d wdata mismatch: expected 0x%08X, got 0x%08X", slot_bits, k, data.wdata, data.p_wdata[k]);
                error = 1;
            end
        end

        if (data.rdata !== exp_rdata) begin
            $error("[SLOT_BITS=%0d] rdata mismatch: expected 0x%08X, got 0x%08X", slot_bits, exp_rdata, data.rdata);
            error = 1;
        end

        if (error) data.print();

        return error;
    endfunction

    //drives the current packet into one DUT configuration (PFX = a or b),
    `define CHECK_ONE(PFX, SLOT_BITS, NUM) \
        PFX``_if.io_addr = item.io_addr; \
        PFX``_if.io_sel  = item.io_sel; \
        PFX``_if.io_we   = item.io_we; \
        PFX``_if.wdata   = item.wdata; \
        for (int k = 0; k < NUM; k++) PFX``_rdata_drv[k] = item.periph_rdata[k]; \
        #1; \
        item.num_periphs = NUM; \
        for (int k = 0; k < NUM; k++) begin \
            item.sel[k]     = PFX``_sel[k]; \
            item.we[k]      = PFX``_we[k]; \
            item.addr[k]    = PFX``_addr[k]; \
            item.p_wdata[k] = PFX``_wdata[k]; \
        end \
        item.rdata = PFX``_if.rdata; \
        error_counter = error_counter + expected_result(item, SLOT_BITS, NUM);

    //runs one directed case on both configurations and prints the results
    `define DIRECTED(NAME, ADDR, SEL, WE) \
        $display("[CASE] %s", NAME); \
        item.io_addr = ADDR; item.io_sel = SEL; item.io_we = WE; \
        `CHECK_ONE(a, A_SLOT_BITS, A_NUM) \
        $write("  [CFG_A] "); item.print(); \
        `CHECK_ONE(b, B_SLOT_BITS, B_NUM) \
        $write("  [CFG_B] "); item.print();

    //test begins
    initial begin
        automatic io_decoder_packet item = new();

        $display("[IO DECODER TEST START]");

        //directed cases: slot boundaries, the unmapped region, and the idle
        //bus. Each peripheral returns 0xA00000NN (NN = its slot number) so the
        //printed rdata shows directly which slot answered.
        item.wdata = 32'hDEAD_BEEF;
        for (int k = 0; k < io_decoder_packet::MAX_PERIPHS; k++)
            item.periph_rdata[k] = 32'hA000_0000 | k;

        `DIRECTED("first word of the window (0x200), write", 10'h000, 1'b1, 1'b1)
        `DIRECTED("last word of slot 0 in CFG_A (0x23C), read", 10'h03C, 1'b1, 1'b0)
        `DIRECTED("first word of slot 1 in CFG_A (0x240), write", 10'h040, 1'b1, 1'b1)
        `DIRECTED("last mapped word in CFG_A (0x2FC), read", 10'h0FC, 1'b1, 1'b0)
        `DIRECTED("first unmapped word in CFG_A (0x300), read", 10'h100, 1'b1, 1'b0)
        `DIRECTED("first unmapped word in CFG_A (0x300), write", 10'h100, 1'b1, 1'b1)
        `DIRECTED("last word of the window (0x3FC), read", 10'h1FC, 1'b1, 1'b0)
        `DIRECTED("slot 1 address (0x240), idle bus", 10'h040, 1'b0, 1'b0)

        //random (constrained-legal) stimulus, checked against both configurations
        repeat (2000) begin
            if (!item.randomize()) $fatal(1, "Randomization failed");

            `CHECK_ONE(a, A_SLOT_BITS, A_NUM)
            `CHECK_ONE(b, B_SLOT_BITS, B_NUM)
        end

        //display results
        $display("[IO DECODER TEST COMPLETE]");
        $display("Total Errors: %0d", error_counter);
        $finish;
    end

endmodule
