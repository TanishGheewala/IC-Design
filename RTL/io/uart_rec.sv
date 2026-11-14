/*
* uart_rec is a uart reciever for communicating with external pc
*/
module uart_rec
    #(  parameter CLK_RATE = 10000000, 
                BAUDRATE = 9600, 
                CLK_BIT = (CLK_RATE/BAUDRATE) - 1,
                HALF_BIT = CLK_BIT/2
    )
    (
        uart_interface uart_if
    );

    //enums for states
    typedef enum logic [2:0] {IDLE, START, DATA, STOP, FINAL} state;

    state uart_state;

    localparam int CNT_WIDTH = $clog2(CLK_BIT + 1);
    logic [CNT_WIDTH-1:0] clk_counter;

    logic serial_in;
    logic serial_in_extra;

    logic [2:0] bit_counter;
    logic [7:0] byte_out;
    logic transmission_done;

    //get serial input every clk
    always_ff @(posedge uart_if.clk) begin
        serial_in_extra <= uart_if.serial_data;
        serial_in <= serial_in_extra;
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
                transmission_done <= 1'b0;

            end

            START: begin
                if(clk_counter == CLK_BIT) begin
                    uart_state <= DATA;
                    clk_counter <= 0;   
                end 
                else begin
                    if(clk_counter == HALF_BIT) begin
                        if(serial_in == 1'b0) begin
                            uart_state <= START;
                            clk_counter <= clk_counter + 1;
                        end else begin
                            uart_state <= IDLE;
                            clk_counter <= 0; 
                        end
                    end
                    else begin
                        uart_state <= START;
                        clk_counter <= clk_counter + 1;
                    end
                end               
            end

            DATA: begin
                //wait for half to ensure value
                //fill in byte bits
                if(clk_counter == HALF_BIT) begin
                        byte_out[bit_counter] <= serial_in;
                end

                //clk count and then increment bit counter
                if(clk_counter == CLK_BIT) begin
                    uart_state  <= (bit_counter == 7) ? STOP : DATA;
                    clk_counter <= 0;
                    bit_counter <= bit_counter + 1;
                end else begin
                    clk_counter <= clk_counter + 1;
                end      
            end

            STOP: begin
                //mark transmission done for output
                bit_counter <= 0;

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
                transmission_done <= 1'b1;
            end

            default: begin
                clk_counter <= 0;
                bit_counter <= 0;
                transmission_done <= 1'b0;
                uart_state <= IDLE;
            end
        endcase

    end

    //output values
    assign uart_if.byte_data = byte_out;
    assign uart_if.uart_tran_done = transmission_done;

endmodule
