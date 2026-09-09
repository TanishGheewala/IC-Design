interface instruction_memory_interface #(
    parameter int ADDR_WIDTH = 10
)();
    logic [ADDR_WIDTH-1:0] addr;
    logic [31:0] inst;

    modport rom_dut
    (
        input addr,
        output inst
    );

endinterface
