/*
*   soc_driver.sv controls sending debug commands over uart.
*/

class gls_driver;
    virtual soc_interface soc_vif;
    event driver_done;
    //typed so every put() is converted to bit [7:0] (generator sends both
    //bit and logic slices; an untyped mailbox rejects the mismatch at get())
    mailbox #(bit [7:0]) driver_mailbox;
    int baud;
    int clk_speed;
    bit [7:0] debug_controller_input;

    //task to send a byte over uart
    task automatic send_rx_line(input logic [7:0] uart_byte, int baud_rate, int clk_speed);

        int baud_wait;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*20;

        //start each byte on the falling clock edge. baud_wait is a whole number
        //of clock periods, so every rx transition then lands mid-period instead
        //of on the rising edge, where it would violate the receiver flop's
        //setup/hold in SDF GLS and turn it X
        @(negedge soc_vif.clk);
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
        clk_speed = 50000000;
        @(posedge soc_vif.clk);

        forever begin
            driver_mailbox.get(debug_controller_input);
            send_rx_line(debug_controller_input, baud, clk_speed);
            repeat(100) @(posedge soc_vif.clk);
            ->driver_done;
        end
    endtask
endclass

