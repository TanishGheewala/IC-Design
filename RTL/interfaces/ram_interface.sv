interface data_memory_interface();
    logic we;
    logic [9:0] addr;
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
