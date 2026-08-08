interface register_file_interface ();

    logic clk;

    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;
    logic [4:0] rd_addr;

    logic [31:0] write_data;
    logic reg_write;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    modport rf_dut
    (
        input clk,
        input rs1_addr,
        input rs2_addr,
        input rd_addr,
        input write_data,
        input reg_write,
        output rs1_data,
        output rs2_data
    );

endinterface
