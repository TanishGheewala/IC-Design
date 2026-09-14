/*
*   Debug Controller: takes instructions from UART and decodes them into signals to control the core.
* 
*   TODO: create a better scoreboard that takes the data input in seq as the check
*   TODO: create random inputs
*/

//debug instructions
`define NOP                 4'b0000
`define CORE_HALT           4'b0001
`define CORE_RESUME         4'b0010
`define CORE_STEP           4'b0011
`define RETURN_REG          4'b0100
`define RETURN_MEM          4'b0101
`define EXIT_DEBUG          4'b0110

//debug_states
`define DEBUG_OFF               3'b000
`define DEBUG_ON                3'b001
`define DATA_LOCATION           3'b010
`define DATA_RETURN             3'b011
`define DATA_RETURN_CLEAN_UP    3'b100
`define DEBUG_CLEAN_UP          3'b101

//data_return_states
//data_address states are the same but without recieve data
`define IDLE                3'b000
`define RECIEVE_DATA        3'b001
`define BYTE_0              3'b010
`define BYTE_1              3'b011
`define BYTE_2              3'b100
`define BYTE_3              3'b101
`define END_TRANSMISION     3'b110

module debug_controller(debug_interface.debug_dut debug_if);

    logic [31:0] core_signals;
    logic [31:0] data_return;
    logic [7:0] data_return_byte;
    logic [7:0] debug_instruction = `NOP;
    logic byte_return_ready = 1'b0;    
    logic [2:0] debug_state = `DEBUG_OFF;
    logic [2:0] data_return_state = `IDLE;
    logic data_return_ready = 1'b0;
    logic [2:0] data_address_state = `IDLE;
    logic data_address_ready = 1'b0;
    logic [31:0] data_address = 0;
    logic get_address = 1'b0;
    logic byte_rx_new = 1'b0;
    logic data_return_done = 1'b0;

    //uart instanstiation
    uart_interface uart_rec_if();
    uart_interface uart_trans_if();

    uart_rec #(.CLK_RATE(100000000), .BAUDRATE(9600)) REC(.uart_if(uart_rec_if.uart_r));
    uart_trans #(.CLK_RATE(100000000), .BAUDRATE(9600)) TRN(.uart_if(uart_trans_if.uart_t));

    //uart_connections debug_controller outputs
    always_comb begin
        uart_rec_if.clk = debug_if.clk;
        uart_rec_if.serial_data = debug_if.rx;

        uart_trans_if.clk = debug_if.clk;
        debug_if.tx = uart_trans_if.serial_data;
    end


    //uart reciever to debug controller conntection
    always_ff@(posedge debug_if.clk) begin
        if(uart_rec_if.uart_tran_done == 1'b1) begin
            debug_instruction <= uart_rec_if.byte_data;
            byte_rx_new <= 1'b1;
        end 
        else begin
            debug_instruction <= 0;
            byte_rx_new <= 1'b0;
        end
    end

    //uart transmission to controller connection
    always_ff@(posedge debug_if.clk) begin
        if(byte_return_ready == 1'b1) begin
            uart_trans_if.byte_data = data_return_byte;
            uart_trans_if.uart_tran_done = 1'b1;
        end else begin
            uart_trans_if.byte_data <= 0;
            uart_trans_if.uart_tran_done <= 1'b0;
        end
    end

    //data return state machine
    //make check for byte return done before moving through state
    //logic for each byte state is to wait for line to clear
    //then send value and move to next byte
    //ex: byte 0 is sent and state moves to byte 1 and waits for clear
    always_ff @(posedge debug_if.clk) begin
        unique case(data_return_state)
            `IDLE: begin
                data_return_done <= 0;
                if(data_return_ready)
                    data_return_state <= `RECIEVE_DATA;
                else
                    data_return_state <= `IDLE;
            end
            `RECIEVE_DATA: begin
                    data_return <= debug_if.data_return_in;
                    byte_return_ready <= 1'b0;
                    data_return_state <= `BYTE_0;
            end

            `BYTE_0: begin
                if(uart_trans_if.line_busy || byte_return_ready) begin
                    data_return_state <= `BYTE_0;
                    byte_return_ready <= 1'b0;
                end else begin
                    data_return_byte <= data_return[7:0];
                    byte_return_ready <= 1'b1;
                    data_return_state <= `BYTE_1;
                end
            end

            `BYTE_1: begin
                if(uart_trans_if.line_busy || byte_return_ready) begin
                    data_return_state <= `BYTE_1;
                    byte_return_ready <= 1'b0;
                end else begin
                    data_return_byte <= data_return[15:8];
                    byte_return_ready <= 1'b1;
                    data_return_state <= `BYTE_2;
                end
            end

            `BYTE_2: begin
                if(uart_trans_if.line_busy || byte_return_ready) begin
                    data_return_state <= `BYTE_2;
                    byte_return_ready <= 1'b0;
                end else begin
                    data_return_byte <= data_return[23:16];
                    byte_return_ready <= 1'b1;
                    data_return_state <= `BYTE_3;
                end
            end

            `BYTE_3: begin
                if(uart_trans_if.line_busy || byte_return_ready) begin
                    data_return_state <= `BYTE_3;
                    byte_return_ready <= 1'b0;
                end else begin
                    data_return_byte <= data_return[31:24];
                    byte_return_ready <= 1'b1;
                    data_return_state <= `END_TRANSMISION;
                end
            end
            
            //allwos byte 3 to send then clears all values
            //then proceeds to idle
            `END_TRANSMISION: begin
                if(uart_trans_if.line_busy || byte_return_ready) begin
                    data_return_state <= `END_TRANSMISION;
                    byte_return_ready <= 1'b0;
                end else begin
                    $display("DATA SENT THROUGH TX");
                    data_return_byte <= 0;
                    byte_return_ready <= 1'b0;
                    data_return_state <= `IDLE;
                    data_return_done <= 1'b1;
                end
            end
        endcase
    end

    //data address state machine gets 32 bit address from uart rx line
    //make check for byte return done before moving through state
    //logic for each byte state is to wait for line to clear
    //then send value and move to next byte
    //ex: byte 0 is sent and state moves to byte 1 and waits for clear
    always_ff @(posedge debug_if.clk) begin
        unique case(data_address_state)
            `IDLE: begin
                if(get_address) begin
                    data_address_state <= `BYTE_0;
                end
                else begin
                    data_address_state <= `IDLE;
                end
            end

            `BYTE_0: begin
                if(!byte_rx_new) begin
                    data_address_state <= `BYTE_0;
                end else begin
                    data_address[31:24] <= debug_instruction;
                    data_address_state <= `BYTE_1;
                end
            end

            `BYTE_1: begin
                if(!byte_rx_new) begin
                    data_address_state <= `BYTE_1;
                end else begin
                    data_address[23:16] <= debug_instruction;
                    data_address_state <= `BYTE_2;
                end
            end

            `BYTE_2: begin
                if(!byte_rx_new) begin
                    data_address_state <= `BYTE_2;
                end else begin
                    data_address[15:8] <= debug_instruction;
                    data_address_state <= `BYTE_3;
                end
            end

            `BYTE_3: begin
                if(!byte_rx_new) begin
                    data_address_state <= `BYTE_3;
                end else begin
                    data_address[7:0] <= debug_instruction;
                    data_address_ready <= 1'b1;
                    data_address_state <= `END_TRANSMISION;
                end
            end
            
            `END_TRANSMISION: begin
                    data_address_state <= `IDLE;
                    data_address_ready <= 1'b0;
                    get_address <= 0;
            end
        endcase
    end

    //debug_state_machine
    always_ff @(posedge debug_if.clk) begin
        unique case(debug_state)

            //core runs normally
            `DEBUG_OFF: begin
                case(debug_instruction)
                    `CORE_HALT: begin
                        debug_if.core_halt <= 1'b1;
                        debug_state <= `DEBUG_ON;
                    end 

                    default: begin
                        debug_if.core_halt <= 1'b0;
                        debug_state <= `DEBUG_OFF;
                    end
                endcase
            end

            //core is paused and gives control to debug_controller
            `DEBUG_ON: begin
                case(debug_instruction)
                    `RETURN_REG: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= `DATA_LOCATION;
                        get_address <= 1'b1;
                    end 

                    `RETURN_MEM: begin
                        debug_if.core_signals <= `RETURN_MEM;
                        debug_state <= `DATA_LOCATION;
                        get_address <= 1'b1;
                    end 

                    `CORE_RESUME: begin
                        debug_if.core_signals <= `NOP;
                        debug_state <= `DEBUG_CLEAN_UP;
                    end

                    default: begin
                        debug_state <= `DEBUG_ON;
                    end
                endcase
            end
            
            //listens on uart rx line for next 4 bytes
            //32 bit word recieved will be used as address for data return
            `DATA_LOCATION: begin
                if(!data_address_ready) begin
                    debug_state <= `DATA_LOCATION;
                end
                else begin
                    debug_if.debug_address <= data_address;
                    debug_state <= `DATA_RETURN;
                end
            end

            //core returns data to debug controller based on command entered\
            //loop backk to DEBUG ON
            `DATA_RETURN: begin
                data_return_ready <= 1'b1;
                debug_state <= `DATA_RETURN_CLEAN_UP;
            end
            
            //debug_controller gives control back to core
            //clears debug controller registers
            `DATA_RETURN_CLEAN_UP: begin
                data_return_ready <= 1'b0;
                if(data_return_done) begin
                    debug_if.core_signals <= 0;
                    debug_if.debug_address <= 0;
                    debug_state <= `DEBUG_ON;
                    data_address <= 0;
                end
                else begin
                    debug_state <= `DATA_RETURN_CLEAN_UP;
                end
            end

            //debug_controller gives control back to core
            //clears debug controller registers
            `DEBUG_CLEAN_UP: begin
                debug_if.core_signals <= 0;
                debug_if.core_halt <= 1'b0;
                data_return_ready <= 1'b0;
                debug_state <= `DEBUG_OFF;
            end

        endcase
    end


endmodule