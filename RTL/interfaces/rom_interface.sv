interface instruction_memory_interface();
    logic [9:0] addr;
    logic [31:0] inst;

    modport rom_dut
    (
        input addr,
        output inst
    );

endinterface
