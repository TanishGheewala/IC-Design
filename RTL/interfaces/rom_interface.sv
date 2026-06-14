interface instruction_memory_interface();
    logic [9:0] addr;
    logic [31:0] data_in;
    logic [31:0] data_out;

    modport rom_dut
    (
        input addr,
        output inst
    );

endinterface
