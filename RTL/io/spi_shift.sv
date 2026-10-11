/*

SPI Shift Register module: bootloader FSM drives this module to shift
data in and out

*/
`timescale 1ns/1ps

module spi_shift #( 
    parameter int FRAME_WIDTH = 8,
    parameter int CLK_DIV = 4 //clk cycle per sclk half-period, >= 3
                )
    (
        input logic clk,
        input logic rst_n,

        input logic start,
        input logic [FRAME_WIDTH-1:0] tx_byte,
        input logic cpol,
        input logic cpha,
        input logic bit_order, //0 = LSB first, 1 = MSB first

        output logic [FRAME_WIDTH-1:0] rx_byte,
        output logic busy,
        output logic done,
        output logic sclk, mosi,
        input logic miso

    );

    localparam int EDGES = 2 * FRAME_WIDTH; //number of edges to shift in/out a frame
    localparam int EDGE_W = $clog2(EDGES); //number of bits to count edges
    localparam int DIV_W = $clog2(CLK_DIV); //number of bits to count clk cycles

typedef enum logic {
    IDLE, TRANSFER
} state_t;
state_t state;

logic [DIV_W-1:0] div_cntr;
logic [EDGE_W-1:0] edge_cntr;

logic sclk_reg;
logic cpha_reg;
logic bit_order_reg;
logic miso_meta, miso_sync;
logic [FRAME_WIDTH-1:0] tx_shift_reg;
logic [FRAME_WIDTH-1:0] rx_shift_reg;


// Reverses bit order, so the shift registers always run MSB-first and
// LSB-first mode is handled only at load (tx) and readout (rx).
function automatic logic [FRAME_WIDTH-1:0] reverse(input logic [FRAME_WIDTH-1:0] x);
    for (int i = 0; i < FRAME_WIDTH; i++)
        reverse[i] = x[FRAME_WIDTH-1-i];
endfunction

// Edge Timing
logic tick, leading, sample, shift, last_edge;

assign tick      = (state == TRANSFER) && (div_cntr == DIV_W'(CLK_DIV-1));
assign leading   = ~edge_cntr[0];                         // even edges lead
assign sample    = tick &&  (leading ^ cpha_reg);          // CPHA=0: leading, CPHA=1: trailing
assign shift     = tick && !(leading ^ cpha_reg)
                        && (edge_cntr != '0);             // CPHA=1: bit 7 is already on mosi
assign last_edge = tick && (edge_cntr == EDGE_W'(EDGES-1));

// Outputs
assign busy    = (state == TRANSFER);
assign sclk    = sclk_reg;
assign mosi    = tx_shift_reg[FRAME_WIDTH-1];
assign rx_byte = bit_order_reg ? rx_shift_reg : reverse(rx_shift_reg);

// miso synchronization: two flops
always_ff @(posedge clk) begin
    if (!rst_n) begin
        miso_meta <= 1'b0;
        miso_sync <= 1'b0;
    end else begin
        miso_meta <= miso;
        miso_sync <= miso_meta;
    end
end


//Control registers: state, counters, sclk, done
// The state machine is clocked by clk, not sclk, so it can run at any speed
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        div_cntr <= 0;
        edge_cntr <= 0;
        sclk_reg <= 0;
        done <= 0;
        cpha_reg <= 0;
        bit_order_reg <= 0;
    end else begin
        done <= 0; //clear done by default
        case (state)
        IDLE: begin
            sclk_reg <= cpol;
            if (start) begin
                state <= TRANSFER;
                div_cntr <= 0;
                edge_cntr <= 0;
                cpha_reg <= cpha;
                bit_order_reg <= bit_order;
        end
    end
        TRANSFER: begin
            if (tick) begin
                div_cntr <= 0;
                edge_cntr <= edge_cntr + 1;
                sclk_reg <= ~sclk_reg;
                if (last_edge) begin
                    state <= IDLE;
                    done <= 1;
                end
            end else begin
                div_cntr <= div_cntr + 1;
            end
        end
    endcase
    end
end

//Datapath registers: tx/rx shift registers
always_ff @(posedge clk) begin
    if (!rst_n) begin
        tx_shift_reg <= '0;
        rx_shift_reg <= '0;
    end else begin
        if (start && state == IDLE)
            tx_shift_reg <= bit_order ? tx_byte : reverse(tx_byte);
        else if (shift)
            tx_shift_reg <= {tx_shift_reg[FRAME_WIDTH-2:0], 1'b0};
        if (sample)
                rx_shift_reg <= {rx_shift_reg[FRAME_WIDTH-2:0], miso_sync};
    end
end

endmodule