/*
* uart_rec is a uart reciever for communicating with the PC
* during fpga testing.
*/
module uart_rec
    #(parameter CLK_RATE = 10000000, 
                BAUDRATE = 9600, 
                CLK_BIT = (CLK_RATE/BAUDRATE) - 1,
                HALF_BIT = CLK_BIT/2
    )
    (
    uart_interaface.uart_r uart_if
    );

    //enums for states
    typedef enum [2:0] {IDLE, START, DATA, STOP, FINAL} state;

    state uart_state = IDLE;
    state uart_next_state = IDLE;

    logic [7:0] clk_counter;

    logic serial_in = 1'b1;
    logic serial_in_extra = 1'b1;

    logic [2:0] bit_counter = 0;
    logic [7:0] byte_out  = 0;
    logic transmission_done = 1'b0;

    //get serial input every clk
    always_ff @(posedge uart_if.clk) begin
        serial_in <= uart_if.serial_data;
        serial_in_extra <= uart_if.serial_data;
    end

    always_ff @(posedge uart_if.clk) begin
        case(uart_state)
            IDLE: begin
                //check for low value
                if(serial_in == 1'b0)
                    uart_state <= START;
                else
                    uart_state <= IDLE;

                clk_counter <= 0;
                bit_counter <= 0;
                uart_next_state <= IDLE;
                transmission_done <= 1'b0;

            end

            START: begin
                //ensure start bit is true bty checking low bit halfway
                if(clk_counter == HALF_BIT) begin
                    if(serial_in == 1'b1) begin
                        uart_next_state <= DATA;
                    end else begin
                        uart_next_state <= IDLE;
                    end
                end
                //go to DATA state on true check, IDLE otherwise
                if(clk_counter == CLK_BIT) begin
                    uart_state <= uart_next_state;
                end else begin
                    uart_state <= START;
                    clk_counter <= clk_counter + 1;
                end               
            end

            DATA: begin
                //wait for half to ensure value
                //fill in byte bits
                if(clk_counter == HALF_BIT) begin
                        byte_out[bit_counter] <= serial_in;
                end

                //change state after last bit
                if(bit_counter == 7) begin
                    uart_next_state <= STOP;
                end else begin
                    uart_next_state <= DATA;
                end

                //clk count and then increment bit counter
                if(clk_counter == CLK_BIT) begin
                    uart_state <= uart_next_state;
                    clk_counter <= 0;
                end else begin
                    clk_counter <= clk_counter + 1;
                end        
            end

            STOP: begin
                //mark transmission done for output
                transmission_done <= 1'b1;

                //count clks per bit, then increment
                if(clk_counter == CLK_BIT) begin
                    uart_state <= FINAL;
                    clk_counter <= 0;
                end else begin
                    uart_state <= STOP;
                    clk_counter <= clk_counter + 1;
                end
            end

            FINAL: begin
                //wait one cycle to go back to listening on IDLE
                uart_state <= IDLE;
                transmission_done <= 1'b0;
            end

            default: begin
                uart_state <= IDLE;
            end
        endcase

    end

    //output values
    assign uart_if.byte_data = byte_out;
    assign uart_if.uart_tran_done = transmission_done;

endmodule
