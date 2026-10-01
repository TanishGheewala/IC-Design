/*
*   soc_driver.sv controls sending debug commands over uart.
*/

class soc_driver;
    virtual soc_interface soc_vif;
    event driver_done;
    mailbox driver_mailbox;
    int baud;
    int clk_speed;

    //task to send a byte over uart
    task automatic send_rx_line(input logic [7:0] uart_byte, int baud_rate, int clk_speed);

        int baud_wait;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        soc_vif.rx = 1'b0;
        #baud_wait;

        for(int i=0; i<8; i++) begin
            soc_vif.rx = uart_byte[i];
            #baud_wait;
        end

        soc_vif.rx = 1'b1;
        #baud_wait;
    endtask

    //sends byte received from mailbox by generator
    task send_debug_command();
        baud = 9600;
        clk_speed = 10000000;
        @(posedge soc_vif.clk);

        forever begin
            soc_packet soc_item;
            driver_mailbox.get(soc_item);
            send_rx_line(soc_item.debug_instruction, baud, clk_speed);
            repeat(1000) @(posedge soc_vif.clk);
            ->driver_done;
        end
    endtask
endclass

