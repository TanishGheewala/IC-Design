/*
*   soc_driver.sv controls sending debug commands over uart.
*/

class soc_driver;
    virtual soc_if v_soc_if;
    event driver_done;
    mailbox driver_mailbox;

    task automatic send_rx_line(input logic [7:0] uart_byte, int baud_rate, int clk_speed);

        int baud_wait;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        v_soc_if.rx = 1'b0;
        #baud_wait;

        for(int i=0; i<8; i++) begin
            v_soc_if.rx = uart_byte[i];
            #baud_wait;
        end

        v_soc_if.rx = 1'b1;
        #baud_wait;
    endtask

    task send_debug_command();
        @(posedgev_soc_if.clk);

        forever begin
            soc_packet soc_item;
            driver_mailbox.get(soc_item);
            send_rx_line(soc_item.debug_instruction, 9600, 10000000);
            ->driver_done;
        end
    endtask
endclass

