/* 
* uart_interface for inputs and outputs to uart receiver.
*/
interface uart_interface();

    logic clk;
    logic serial_data;
    logic [7:0] byte_data;
    logic uart_tran_done;
    logic done;
    logic rst_n;

    modport uart_r(
        input clk,
        input serial_data,
        input rst_n,
        output byte_data,
        output uart_tran_done
    );

    modport uart_t(
        input clk,
        input byte_data,
        input uart_tran_done,
        input rst_n,
        output serial_data,
        output done
    );
endinterface