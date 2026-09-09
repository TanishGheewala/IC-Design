/*
* debug_controller_tb is the top level testbench for the debug_controller
*/
`include "debug_controller_packet.sv"

`timescale 1ns/1ps
module debug_controller_tb;

    logic clk;

    //interface
    debug_interface debug_if();
    assign debug_if.clk = clk;

    //DUT
    debug_controller DUT (
        .debug_if(debug_if.debug_dut)
    );

    logic [7:0] test_instruction_sequence [];

    //checks to make sure data returning from core is correct
    //first asserts core is off/on
    //second checks that returned data matches sent command
    function void expected_outcome_tx_line(debug_controller_packet data);;
        case(data.debug_command)
            debug_controller_packet::CORE_HALT: begin
                assert (data.core_halt == 1'b1) 
                else   $error("CORE IS NOT STOPPED, actual: %0h, expected: %0h", data.core_halt, 1);
            end
            debug_controller_packet::RETURN_REG: begin
                assert (data.core_halt == 1'b1) 
                else   $error("CORE IS NOT STOPPED, actual: %0h, expected: %0h", data.core_halt, 1);
                assert (data.data_return_out == debug_controller_packet::RETURN_REG) 
                else   $error("DATA RETURNED DOES NOT MATCH, actual: %0h, expected: %0h", data.data_return_out, debug_controller_packet::RETURN_REG);
            end
            debug_controller_packet::RETURN_MEM: begin
                assert (data.core_halt == 1'b1) 
                else   $error("CORE IS NOT STOPPED, actual: %0h, expected: %0h", data.core_halt, 1);
                assert (data.data_return_out == debug_controller_packet::RETURN_MEM) 
                else   $error("DATA RETURNED DOES NOT MATCH, actual: %0h, expected: %0h", data.data_return_out, debug_controller_packet::RETURN_MEM);
            end
            debug_controller_packet::CORE_RESUME: begin
                assert (data.core_halt == 1'b0) 
                else   $error("CORE IS NOT RUNNIG, actual: %0h, expected: %0h", data.core_halt, 0);
            end
        endcase
    endfunction

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
    task automatic recieve_tx_line(ref debug_controller_packet data, int baud_rate, int clk_speed);

        int baud_wait;
        logic [7:0] uart_byte;
        baud_wait = (clk_speed/baud_rate) - 1;
        baud_wait = baud_wait*10;

        //4 loops for full 32 bit word to be sent as 4 bytes
        for(int j=0; j<4; j++) begin
            @(posedge DUT.uart_trans_if.line_busy);

            //2 to account for uart trans idle and start
            repeat(2) #baud_wait;
            for(int i=0; i<8; i++) begin
                uart_byte[i] = debug_if.tx;
                #baud_wait;
            end
            #baud_wait;
            //sets bytes in correct spot -- should probably change to multidimension array
            if(j == 0)
                data.data_return_out[7:0] = uart_byte;
            else if(j == 1)
                data.data_return_out[15:8] = uart_byte;
            else if(j == 2)
                data.data_return_out[23:16] = uart_byte;
            else if(j == 3)
                data.data_return_out[31:24] = uart_byte;
        end
        $display("return: %0h", data.data_return_out);
    endtask

    //task to send sequence of commands to debug controller
    task automatic debug_instruction_sequence(input logic [7:0] seq [], ref debug_controller_packet debug_data, input int baud_rate, int clk_speed);

        @(posedge clk);

        //runs all instructions through
        foreach (seq[i]) begin
            $display("[INSTRUCTION #%d: %0h]", i, seq[i]);
            @(posedge clk);
            send_rx_line(seq[i], baud_rate, clk_speed);
            wait(DUT.uart_rec_if.uart_tran_done);

            //3 to account for internal pipeline
            repeat(3) @(posedge clk);
            debug_data.debug_command = seq[i];
            @(posedge clk);
            debug_if.data_return_in = debug_if.core_signals;

            //check recieved value
            if(seq[i] > 3) begin
                recieve_tx_line(debug_data, baud_rate, clk_speed);
            end
            //ensures all uart stuff is done
            repeat(200) @(posedge clk);

            //updates and checks output
            debug_data.core_halt = debug_if.core_halt;
            debug_data.debug_state = DUT.debug_state;
            expected_outcome_tx_line(debug_data);
            $display(debug_data.convert_to_string());
        end
        
        

    endtask
    
    //clk
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //test begins
    initial begin
        debug_controller_packet debug_controller_item = new();

        debug_if.rx = 1'b1;
        
        $display("[DEBUG CONTROLLER STATE TEST START]");

        @(posedge clk)

        test_instruction_sequence = new[7];
        test_instruction_sequence = '{debug_controller_packet::NOP, debug_controller_packet::CORE_HALT, 
            debug_controller_packet::CORE_RESUME, debug_controller_packet::CORE_HALT, 
            debug_controller_packet::RETURN_REG, debug_controller_packet::RETURN_MEM,
            debug_controller_packet::CORE_RESUME};

            debug_instruction_sequence(test_instruction_sequence, debug_controller_item, 9600, 100000000);

        //display results
        $display("[DEBUG TEST COMPLETE]");
        $finish;
    end


endmodule
