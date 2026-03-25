interface uart_interaface();

    logic clk;
    logic serial_data;
    logic [7:0] byte_data;
    logic uart_tran_done;

    modport uart_r(
        input clk,
        input serial_data,
        output byte_data,
        output uart_tran_done
    );
endinterface