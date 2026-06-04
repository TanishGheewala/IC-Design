// Data Memory - Random Access Memory (RAM)

`include "macros.vh"

module data_memory
(
    input clk;
    input we;
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    output reg [`DATA_WIDTH-1:0] data_out
);

// RAM Array
reg [`DATA_WIDTH-1:0] ram [0:`MEM_DEPTH-1];

always @(posedge clk) begin
    if
end
endmodule