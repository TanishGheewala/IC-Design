// Testbench for data_memory_sram8k.v

`timescale 1ns/1ps

module tb_sram8k;

    reg         clk = 0;
    reg         we;
    reg  [3:0]  wmask;
    reg  [12:0] addr;
    reg  [31:0] data_in;
    wire [31:0] data_out;

    integer errors = 0;

    data_memory_sram8k dut (
        .clk      (clk),
        .we       (we),
        .wmask    (wmask),
        .addr     (addr),
        .data_in  (data_in),
        .data_out (data_out)
    );

    always #5 clk = ~clk;

    task write_masked(
        input [12:0] a,
        input [31:0] d,
        input [3:0]  mask
    );
    begin
        @(negedge clk);
        we      = 1'b1;
        wmask   = mask;
        addr    = a;
        data_in = d;

        @(negedge clk);
        we    = 1'b0;
        wmask = 4'b0000;
    end
    endtask

    task write_word(
        input [12:0] a,
        input [31:0] d
    );
    begin
        write_masked(a, d, 4'b1111);
    end
    endtask

    task read_check(
        input [12:0] a,
        input [31:0] expected
    );
    begin
        @(negedge clk);
        we      = 1'b0;
        wmask   = 4'b0000;
        addr    = a;
        data_in = 32'b0;

        // Account for the synchronous SRAM read latency.
        @(posedge clk);
        @(posedge clk);

        if (data_out !== expected)
        begin
            $display(
                "FAIL: addr=%0h expected=%h got=%h",
                a,
                expected,
                data_out
            );

            errors = errors + 1;
        end
        else
        begin
            $display(
                "PASS: addr=%0h data=%h",
                a,
                data_out
            );
        end
    end
    endtask

    initial
    begin
        we      = 1'b0;
        wmask   = 4'b0000;
        addr    = 13'b0;
        data_in = 32'b0;

        repeat (3) @(negedge clk);

        // Check normal full-word writes across all four SRAM banks.
        write_word(13'h0000, 32'hAAAA_0000);
        write_word(13'h0004, 32'hAAAA_0001);
        write_word(13'h0800, 32'hBBBB_0000);
        write_word(13'h1000, 32'hCCCC_0000);
        write_word(13'h1800, 32'hDDDD_0000);
        write_word(13'h1FFC, 32'hDDDD_FFFF);

        read_check(13'h0000, 32'hAAAA_0000);
        read_check(13'h0004, 32'hAAAA_0001);
        read_check(13'h0800, 32'hBBBB_0000);
        read_check(13'h1000, 32'hCCCC_0000);
        read_check(13'h1800, 32'hDDDD_0000);
        read_check(13'h1FFC, 32'hDDDD_FFFF);

        // Check individual byte-write lanes.
        write_word(13'h0020, 32'h1122_3344);

        write_masked(
            13'h0020,
            32'hDEAD_BBAA,
            4'b0001
        );
        read_check(13'h0020, 32'h1122_33AA);

        write_masked(
            13'h0020,
            32'hDEAD_BBAA,
            4'b0010
        );
        read_check(13'h0020, 32'h1122_BBAA);

        write_masked(
            13'h0020,
            32'hDEAD_BBAA,
            4'b0100
        );
        read_check(13'h0020, 32'h11AD_BBAA);

        write_masked(
            13'h0020,
            32'hDEAD_BBAA,
            4'b1000
        );
        read_check(13'h0020, 32'hDEAD_BBAA);

        // Check low and high halfword masks.
        write_word(13'h0024, 32'h1122_3344);

        write_masked(
            13'h0024,
            32'hA1B2_A1B2,
            4'b0011
        );
        read_check(13'h0024, 32'h1122_A1B2);

        write_masked(
            13'h0024,
            32'hC3D4_C3D4,
            4'b1100
        );
        read_check(13'h0024, 32'hC3D4_A1B2);

        // Confirm that later reads from different banks still work.
        read_check(13'h0000, 32'hAAAA_0000);
        read_check(13'h1800, 32'hDDDD_0000);
        read_check(13'h0800, 32'hBBBB_0000);
        read_check(13'h1000, 32'hCCCC_0000);

        if (errors == 0)
            $display("\n*** ALL CHECKS PASSED ***");
        else
            $display(
                "\n*** %0d CHECK(S) FAILED ***",
                errors
            );

        $finish;
    end

endmodule
