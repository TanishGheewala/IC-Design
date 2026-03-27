module uart_trans
    #(parameter CLK_RATE = 10000000, 
                BAUDRATE = 9600, 
                CLK_BIT = (CLK_RATE/BAUDRATE) - 1,
                HALF_BIT = CLK_BIT/2
    )
    (
        uart_interface.uart_t uart_if
    );

    //enums for states
    typedef enum logic [2:0] {IDLE, START, DATA, STOP, FINAL} state;
    state uart_state = IDLE;
    
    //transmission registers
    logic [31:0] clk_counter;
    logic serial_out = 1'b1;
    logic [2:0] bit_counter = 0;
    logic [7:0] byte_in  = 0;

    always_ff @(posedge uart_if.clk) begin
        
        case(uart_state)
            IDLE: begin
                //cleans inputs
                serial_out <= 1'b1;
                clk_counter <= 0;
                bit_counter <= 0;

                //transmits on tran_done_signal
                if(uart_if.uart_tran_done == 1'b1) begin
                    byte_in <= uart_if.byte_data;
                    uart_state <= START;
                end else begin
                    uart_state <= IDLE;
                end

            end

            START: begin
                //outputs start bit for 1 frame
                serial_out <= 1'b0;
                
                if(clk_counter < CLK_BIT) begin
                    clk_counter <= clk_counter + 1;
                    uart_state = START;
                end else begin
                    clk_counter <= 0;
                    uart_state <= DATA;
                end

            end

            DATA: begin
                //outputs all data bits each taking 1 frame
                serial_out <= byte_in[bit_counter];
                
                if(clk_counter < CLK_BIT) begin
                    clk_counter <= clk_counter + 1;
                    uart_state = DATA;
                end else begin
                    clk_counter <= 0;
                    if(bit_counter < 7) begin
                        bit_counter = bit_counter + 1;
                        uart_state = DATA;
                    end else begin
                        bit_counter <= 0;
                        uart_state <= STOP;
                    end
                end
            end

            STOP: begin    
                //outputs stop bit for 1 frame
                serial_out <= 1'b1;
                
                if(clk_counter < CLK_BIT) begin
                    clk_counter <= clk_counter + 1;
                    uart_state = STOP;
                end else begin
                    clk_counter <= 0;
                    uart_state <= FINAL;
                end
            end

            FINAL: begin
                //extra clk stop before entering another state
                //ensures functionality with back to back inputs
                uart_state <= IDLE;
            end

            default: uart_state <= IDLE;
        endcase
    end

    //output
    assign uart_if.serial_data = serial_out;

endmodule