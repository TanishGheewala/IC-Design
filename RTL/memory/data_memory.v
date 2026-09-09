// Data Memory - Random Access Memory (RAM)

`include "macros.vh"

module data_memory
#(
    parameter ADDR_WIDTH = `ADDR_WIDTH,
    parameter DATA_WIDTH = `DATA_WIDTH,
    parameter MEM_DEPTH = `MEM_DEPTH,
    parameter MEM_INITIAL_FILE = ""
) (
    input clk,
    input we,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out
);

// RAM Array
reg [DATA_WIDTH-1:0] ram [0:MEM_DEPTH-1];

wire [ADDR_WIDTH-3:0] word_addr = addr[ADDR_WIDTH-1:2];

// Load initial data when a file is provided
initial begin
    if (MEM_INITIAL_FILE != "") begin
        $readmemh(MEM_INITIAL_FILE, ram);
    end
end

// Combinational read for the single-cycle datapath
always @(*) begin
    data_out = ram[word_addr];
end

// Synchronous write
always @(posedge clk) begin
    if (we) begin
        ram[word_addr] <= data_in;
    end
end

endmodule