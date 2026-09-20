/*
* soc_debug_test.sv tests the debug functionality when interacting with the core.
*/
`include "soc_debug_packet.sv"

module soc_debug_test;
    logic clk;
    logic rx;
    logic tx;

    soc soc_dut(.clk(clk), .rx(rx), .tx(tx));

    //task to send uart byte as serial data to rx line
    task automatic send_rx_line(input logic [7:0] uart_byte, int baud_rate, int clk_speed);

        int baud_wait;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        debug_if.rx = 1'b0;
        #baud_wait;

        for(int i=0; i<8; i++) begin
            debug_if.rx = uart_byte[i];
            #baud_wait;
        end

        debug_if.rx = 1'b1;
        #baud_wait
        assert(uart_byte == DUT.uart_rec_if.byte_data)
                else $error("Incorrect byte received expected: %0h, actual: %0h", uart_byte, DUT.uart_rec_if.byte_data);

    endtask

    //task recieve serial byte from debug controller
    task automatic recieve_tx_line(output logic [31:0] tx_line_return, int baud_rate, int clk_speed);

        int baud_wait;
        logic [7:0] uart_byte;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        for(int j=0; j<4; j++) begin
            @(negedge debug_if.tx)
            data.core_halt = debug_if.core_halt;
            data.debug_state = DUT.debug_state;
            //1 1/2 to account for uart trans idle and start and take from middle of transmission
            #(baud_wait + (baud_wait / 2));

            for(int i=0; i<8; i++) begin
                uart_byte[i] = debug_if.tx;
                #baud_wait;
            end
            #(baud_wait / 2); 

            //sets bits in correct position -- simulating python script
            if(j == 0) begin
                tx_line_return[7:0] = uart_byte;
            end
            else if(j == 1) begin
                tx_line_return[15:8] = uart_byte;
            end
            else if(j == 2) begin
                tx_line_return[23:16] = uart_byte;
            end
            else if(j == 3) begin
                tx_line_return[31:24] = uart_byte;
            end
        end
    endtask

endmodule