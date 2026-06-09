// Data Memory - Random Access Memory (RAM)

`include "macros.vh"

module data_memory
#(
    input clk,
    input we,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    output reg [`DATA_WIDTH-1:0] data_out
);

// RAM Array
reg [`DATA_WIDTH-1:0] ram [0:`MEM_DEPTH-1];

wire [`ADDR_WIDTH-3:0] word_addr = addr[`ADDR_WIDTH-1:2];

// Always reads, writes only when we=1
always @(posedge clk) begin
    if (we) begin
        ram[word_addr] <= data_in;
    end
    data_out <= ram[word_addr];
end

endmodule
