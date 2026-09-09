interface data_memory_interface #(
    parameter int ADDR_WIDTH = 10
)();
    logic we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [31:0] data_in;
    logic [31:0] data_out;

    modport ram_dut
    (
        input we,
        input addr,
        input data_in,
        output data_out
    );

endinterface
