/*
* spi_shift_checks is an SVA checker for the SPI shift engine. It is attached
* with bind, so the same checks run on every spi_shift instance - standalone
* in its own testbench or inside spi_master (and the boot FSM later):
*
*   bind spi_shift spi_shift_checks #(.FRAME_WIDTH(FRAME_WIDTH), .CLK_DIV(CLK_DIV)) u_checks (.*);
*
* It only uses spi_shift's ports, so it checks behavior, not implementation.
* fail_count is read by the testbench and added to its error total.
*/
`timescale 1ns/1ps

module spi_shift_checks #(
    parameter int FRAME_WIDTH = 8,
    parameter int CLK_DIV     = 4
)(
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic cpol,
    input logic busy,
    input logic done,
    input logic sclk
);

    localparam int EDGES        = 2 * FRAME_WIDTH;
    localparam int FRAME_CYCLES = EDGES * CLK_DIV;   //start edge to done

    int fail_count = 0;

    function void fail(string what);
        fail_count++;
        $error("[spi_shift_checks %m] %s", what);
    endfunction

    //sclk is a flop output, so a toggle made on one clk edge is seen as
    //sclk != sclk_d on the next one. edges counts toggles since the last
    //accepted start. A change seen right after the start edge is sclk moving
    //to a new idle level (cpol written just before start), not a frame edge.
    //cpol_start is the idle level the frame started from; the live cpol may
    //already hold the next frame's value by the done cycle.
    logic sclk_d;
    logic toggled;
    logic just_started;
    int   edges;
    logic cpol_start;

    assign toggled = (sclk !== sclk_d);

    always_ff @(posedge clk) begin
        sclk_d       <= sclk;
        just_started <= start && !busy;
        if (!rst_n || (start && !busy))
            edges <= 0;
        else if (toggled && !just_started)
            edges <= edges + 1;
        if (start && !busy)
            cpol_start <= cpol;
    end

    //an accepted start gives exactly FRAME_CYCLES busy cycles, then one done.
    //A start while busy can't stretch or restart the frame.
    a_frame_length: assert property (@(posedge clk) disable iff (!rst_n)
        (start && !busy) |=> (busy && !done) [*FRAME_CYCLES] ##1 (done && !busy))
        else fail("frame length: expected FRAME_CYCLES busy cycles then done");

    //done is a single-cycle pulse
    a_done_pulse: assert property (@(posedge clk) disable iff (!rst_n)
        done |=> !done)
        else fail("done held for more than one cycle");

    //busy only ends with done (except through reset)
    a_busy_ends_with_done: assert property (@(posedge clk) disable iff (!rst_n)
        ($past(rst_n) && $fell(busy)) |-> done)
        else fail("busy dropped without done");

    //exactly 2*FRAME_WIDTH sclk edges per frame (the last one is still
    //pending in 'toggled' on the done cycle)
    a_edge_count: assert property (@(posedge clk) disable iff (!rst_n)
        done |-> (edges + int'(toggled)) == EDGES)
        else fail($sformatf("frame had %0d sclk edges, expected %0d", edges + int'(toggled), EDGES));

    //frame ends with sclk back at the idle level it started from
    a_end_level: assert property (@(posedge clk) disable iff (!rst_n)
        done |-> sclk == cpol_start)
        else fail("sclk not at cpol when the frame ended");

    //while idle (and cpol not just changed), sclk sits at cpol
    a_idle_level: assert property (@(posedge clk) disable iff (!rst_n)
        ($past(rst_n) && !busy && $past(!busy) && $stable(cpol)) |-> sclk == cpol)
        else fail("sclk not at cpol while idle");

endmodule
