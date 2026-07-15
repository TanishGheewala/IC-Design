`timescale 1ns/1ps

module ram_test;

    logic clk;
    logic we;
    logic [9:0] addr;
    logic [31:0] data_in;
    logic [31:0] data_out;

    data_memory dut (
        .clk(clk),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        we = 0; addr = 0; data_in = 0;
        @(posedge clk);
        @(posedge clk);
        we = 1; addr = 0; data_in = 32'hABCD1234;
        @(posedge clk);
        we = 0;
        @(posedge clk);
        $display("Read from addr 0: 0x%08X", data_out);
        @(posedge clk);
        $display("RAM test done");
        $finish;
    end

endmodule
