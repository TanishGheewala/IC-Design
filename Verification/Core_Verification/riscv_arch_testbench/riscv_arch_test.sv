`timescale 1ns/1ps

module riscv_arch_test_tb #(
    parameter string TEST_HEX = "current_test.hex"
);

    localparam int ADDR_WIDTH = 20;
    localparam int MEM_DEPTH  = 262144;
    localparam int WORD_ADDR_WIDTH = $clog2(MEM_DEPTH);

    localparam int MAX_CYCLES = 1000000;
    localparam logic TRACE_ENABLE = 1'b0;

    localparam logic [31:0] TEST_STATUS_ADDR =
        32'h000F_F000;

    logic clk;
    logic rst_n;

    logic [31:0] instruction_memory [0:MEM_DEPTH-1];
    logic [31:0] data_memory        [0:MEM_DEPTH-1];
    logic [31:0] memory_read_q;

    logic [WORD_ADDR_WIDTH-1:0] instruction_word_address;
    logic [WORD_ADDR_WIDTH-1:0] data_word_address;

    int unsigned cycle_counter;

    core_interface #(
        .ROM_ADDR_WIDTH    (ADDR_WIDTH),
        .MEMORY_ADDR_WIDTH (ADDR_WIDTH)
    ) core_if();

    core #(
        .ADDR_WIDTH       (ADDR_WIDTH),
        .MEM_DEPTH        (MEM_DEPTH),
        .ROM_INITIAL_FILE (TEST_HEX),
        .RAM_INITIAL_FILE (TEST_HEX),
        .DEBUG_PRINT      (1'b0)
    ) dut (
        .core_if(core_if)
    );

    // Clock generation
    initial
        clk = 1'b0;

    always #5 clk = ~clk;

    // Core control inputs
    always_comb
    begin
        core_if.clk                          = clk;
        core_if.rst_n                        = rst_n;
        core_if.core_halt                    = 1'b0;
        core_if.debug_controller_instruction = 8'h00;
        core_if.debug_address                = 32'b0;
    end

    assign instruction_word_address =
        core_if.rom_address[WORD_ADDR_WIDTH+1:2];

    assign data_word_address =
        core_if.memory_address[WORD_ADDR_WIDTH+1:2];

    assign core_if.rom_read =
        instruction_memory[instruction_word_address];

    assign core_if.memory_read =
        memory_read_q;

    // Load the official architecture-test image.
    initial
    begin
        $display(
            "RVCP-INFO: Loading test image %s",
            TEST_HEX
        );

        $readmemh(TEST_HEX, instruction_memory);
        $readmemh(TEST_HEX, data_memory);
    end

    // Model synchronous SRAM reads and masked writes.
    always_ff @(posedge clk)
    begin
        if (!rst_n)
        begin
            memory_read_q <= 32'b0;
        end
        else
        begin
            memory_read_q <=
                data_memory[data_word_address];

            if (core_if.memory_write_en)
            begin
                if (core_if.memory_write_mask[0])
                    data_memory[data_word_address][7:0] <=
                        core_if.memory_write[7:0];

                if (core_if.memory_write_mask[1])
                    data_memory[data_word_address][15:8] <=
                        core_if.memory_write[15:8];

                if (core_if.memory_write_mask[2])
                    data_memory[data_word_address][23:16] <=
                        core_if.memory_write[23:16];

                if (core_if.memory_write_mask[3])
                    data_memory[data_word_address][31:24] <=
                        core_if.memory_write[31:24];
            end
        end
    end

    // Reset sequence
    initial
    begin
        rst_n = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);

        rst_n = 1'b1;
    end

    // Optional cycle-by-cycle trace
    always_ff @(posedge clk)
    begin
        if (rst_n && TRACE_ENABLE)
        begin
            $display(
                "RVCP-TRACE: cycle=%0d pc=%08h inst=%08h rs1=%08h rs2=%08h alu=%08h",
                cycle_counter,
                dut.pc,
                core_if.rom_read,
                dut.rf_if.rs1_data,
                dut.rf_if.rs2_data,
                dut.alu_if.out_data
            );
        end
    end

    // Detect the official architecture-test completion write.
    always_ff @(posedge clk)
    begin
        if (!rst_n)
        begin
            cycle_counter <= 0;
        end
        else
        begin
            cycle_counter <= cycle_counter + 1;

            if (
                core_if.memory_write_en &&
                (dut.alu_if.out_data == TEST_STATUS_ADDR)
            )
            begin
                if (core_if.memory_write == 32'd1)
                    $display("RVCP-SUMMARY: TEST PASSED");
                else if (core_if.memory_write == 32'd3)
                    $display("RVCP-SUMMARY: TEST FAILED");
                else
                    $display(
                        "RVCP-SUMMARY: INVALID TEST STATUS"
                    );

                $finish;
            end

            if (cycle_counter >= MAX_CYCLES)
            begin
                $display("RVCP-SUMMARY: TEST TIMED OUT");
                $finish;
            end
        end
    end

endmodule