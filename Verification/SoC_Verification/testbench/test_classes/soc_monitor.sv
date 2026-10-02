/*
*   soc_monitor.sv controls sending debug commands over uart.
*
*   TODO: add a way to check core state (regsiters, memory, pc),
*   and a way to match instruction with address sent when instruction
*   is followed by address
*/

class soc_monitor;
    virtual soc_interface soc_vif;
    mailbox scoreboard_mailbox;
    int baud;
    int clk_speed;
    event monitor_done;
    int baud_wait;

    //task recieve serial byte from debug controller
    task automatic receive_tx_line(output logic [31:0] tx_line_return);

        logic [7:0] uart_byte;

        for(int j=0; j<4; j++) begin
            @(negedge soc_vif.tx);
            //1 1/2 to account for uart trans idle and start and take from middle of transmission
            #(baud_wait + (baud_wait / 2));

            for(int i=0; i<8; i++) begin
                uart_byte[i] = soc_vif.tx;
                #(baud_wait);
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
        $display("tx_line_return: %0h", tx_line_return);
    endtask

    task receive_soc_message();

        baud = 9600;
        clk_speed = 100000000;
        baud_wait = (clk_speed/baud) - 1;
        baud_wait = baud_wait*10;

        @(posedge soc_vif.clk);

        forever begin
            soc_packet soc_item;
            soc_item = new();
            $display("Monitor tx line start...");
            receive_tx_line(soc_item.tx_line_return);
            @(posedge soc_vif.clk);
            scoreboard_mailbox.put(soc_item);
            ->monitor_done;
        end
    endtask
endclass

