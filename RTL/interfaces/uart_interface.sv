/* 
* uart_interface for inputs and outputs to uart receiver.
*/
interface uart_interface();

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

    modport uart_t(
        input clk,
        input byte_data,
        input uart_tran_done,
        output serial_data
    );
endinterface