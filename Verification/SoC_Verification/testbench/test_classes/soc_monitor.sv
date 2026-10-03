/*
*   soc_monitor.sv controls sending debug commands over uart.
*
*/

class soc_monitor;
    virtual soc_interface soc_vif;
    virtual core_probe core_probe_vif;
    mailbox scoreboard_mailbox;
    mailbox monitor_mailbox;
    int baud;
    int clk_speed;
    event monitor_done;
    event driver_done;
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
    endtask

    task receive_soc_message();

        baud = 9600;
        clk_speed = 100000000;
        baud_wait = (clk_speed/baud) - 1;
        baud_wait = baud_wait*10;

        @(posedge soc_vif.clk);

        forever begin
            soc_packet soc_item;
            soc_packet soc_input_address;
            soc_item = new();
            soc_input_address = new();
            monitor_mailbox.get(soc_item);
            case(soc_item.debug_instruction)
                soc_packet::RETURN_REG,
                soc_packet::RETURN_MEM: begin
                    receive_tx_line(soc_item.tx_line_return);
                end

                default: begin
                    @(driver_done);
                end
            endcase
            soc_item.registers = core_probe_vif.registers;
            soc_item.memory = core_probe_vif.memory;
            soc_item.core_halt = core_probe_vif.core_halt;
            @(posedge soc_vif.clk);
            scoreboard_mailbox.put(soc_item);
            ->monitor_done;
        end
    endtask
endclass

