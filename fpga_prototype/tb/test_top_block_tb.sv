`timescale 1ns/1ps

/*
* test_top_block_tb tests the uart receiver and transmitter.
* It also tests the custom logic for dividing the uart inputs
* into the 3 inputs of the ALU. This tests will ensure that 
* the fpga will be able to communicate with the python script
* though uart.
*/
module test_top_block_tb;
    
    //test registers
    logic clk;
    logic [7:0] uart_input_data;
    logic uart_go;
    logic [31:0] alu_output;
    logic t_done;
    logic serial;

    //clock signal
    initial clk = 0;
    always #5 clk <= ~clk;

    //transmitter
    uart_interface uart_if_t();

    uart_trans #(.CLK_RATE(100000000), .BAUDRATE(9600))
        UT00(.uart_if(uart_if_t));
    
    //reciever plus alu combo
    test_top_block TT00(.clk(clk), .uart_in(serial), .alu_out(alu_output), .transmission_done(t_done));

    //assign uart transmitter inputs
    assign uart_if_t.byte_data = uart_input_data;
    assign uart_if_t.clk = clk;
    assign uart_if_t.uart_tran_done = uart_go;
    assign serial = uart_if_t.serial_data;

    //simple addition test
    initial begin
        #80;
        @(posedge clk) uart_input_data = 8'b00011001;
        uart_go = 1;
        @(posedge clk) uart_go = 0;
        @(posedge t_done);
        #80;
        @(posedge clk) uart_input_data = 8'b00011001;
        uart_go = 1;
        @(posedge clk) uart_go = 0;
        @(posedge t_done);
        #80;
        @(posedge clk) uart_input_data = 8'b00011001;
        uart_go = 1;
        @(posedge clk) uart_go = 0;
        @(posedge t_done);
        #80;
        $finish;
    end
endmodule