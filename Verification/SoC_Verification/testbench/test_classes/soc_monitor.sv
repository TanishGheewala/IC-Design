/*
*   soc_monitor.sv controls sending debug commands over uart.
*/

class soc_monitor;
    virtual soc_interface soc_vif;
    mailbox scoreboard_mailbox;
    int baud;
    int clk_speed;

    //task recieve serial byte from debug controller
    task automatic receive_tx_line(output logic [31:0] tx_line_return, int baud_rate, int clk_speed);

        int baud_wait;
        logic [7:0] uart_byte;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        for(int j=0; j<4; j++) begin
            //1 1/2 to account for uart trans idle and start and take from middle of transmission
            #(baud_wait + (baud_wait / 2));

            for(int i=0; i<8; i++) begin
                uart_byte[i] = soc_vif.tx;
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

    task receive_soc_message();

        baud = 9600;
        clk_speed = 10000000;

        //monitor loop
        forever begin
            soc_packet soc_item;
            soc_item = new();
            @(negedge soc_vif.tx);
            receive_tx_line(soc_item.tx_line_return, baud, clk_speed);
            scoreboard_mailbox.put(soc_item);
        end
    endtask
endclass

