/*
*   Debug Controller: takes instructions from UART and decodes them into signals to control the core.
* 
*   TODO: WRITE BOOTLOADER DEBUG STATE LOGIC
*   (essentially wait for bootloader to say its done the go forward)
*
*/
module debug_controller_v2(debug_interface_v2 debug_if);
    //debug controller overall state
    //OFF when core running
    //MENU when core halted and awaitin command
    //TX when transmiting to user PC
    //RX when receiving from user PC
    typedef enum logic [2:0] {
        DEBUG_OFF,
        DEBUG_MENU,
        DEBUG_RX,
        PROP_DELAY,
        DEBUG_TX,
        BOOTLOAD,
        CLEAN_UP
    }debug_state_t;

    //commands user can input to mircrocontroller
    typedef enum logic [7:0] {
        NOP,
        CORE_HALT,
        RETURN_REG,
        RETURN_MEM,
        RETURN_PC,
        FLASH_WRITE,
        CORE_RESUME = 8'hff
    }debug_command_t;

    //transmission and recieve word stages
    typedef enum logic [2:0] {
        TRX_IDLE,
        RECIEVE_DATA,
        BYTE_0,
        BYTE_1,
        BYTE_2,
        BYTE_3,
        END_TRANSMISION
    }debug_trx_state_t;

    //uart instanstiation
    uart_interface uart_rec_if();
    uart_interface uart_trans_if();

    //uart
    uart_rec #(.CLK_RATE(80000000), .BAUDRATE(9600)) REC(.uart_if(uart_rec_if.uart_r));
    uart_trans #(.CLK_RATE(80000000), .BAUDRATE(9600)) TRN(.uart_if(uart_trans_if.uart_t));

    //interface connections output
    always_comb begin
        uart_rec_if.clk = debug_if.clk;
        uart_trans_if.clk = debug_if.clk;
        debug_if.command = debug_command;
        debug_if.tx = uart_trans_if.serial_data;
        debug_if.core_halt = halt;
        uart_rec_if.serial_data = debug_if.rx;
    end
    
    //state updates
    debug_state_t debug_state = DEBUG_OFF;
    debug_state_t next_debug_state = DEBUG_OFF;

    //state logic
    logic [7:0] debug_command = 0;
    logic debug_rx_done;
    logic debug_tx_done;
    logic halt;
    logic [31:0] tx_word;
    logic [31:0] rx_word;
    logic [1:0] delay_counter = 0;
    logic [31:0] address_out;

    //debug controller state register updates
    always_ff @(posedge debug_if.clk or negedge debug_if.rst_n) begin
        if(!debug_if.rst_n) begin
            debug_state <= DEBUG_OFF;
            debug_command <= 0;
            tx_word <= 0;
            delay_counter <= 0;
            address_out <= 0;
        end
        else begin
            debug_state <= next_debug_state;
            unique case(debug_state)
                DEBUG_MENU, DEBUG_OFF: begin
                    address_out <= 0;
                    if(uart_rec_if.uart_tran_done)
                        debug_command <= uart_rec_if.byte_data;
                end

                DEBUG_RX: begin
                    address_out <= rx_word;
                end

                PROP_DELAY: begin
                    delay_counter <= delay_counter + 1;
                end
                
                DEBUG_TX: begin
                    tx_word <= debug_if.core_data;
                end

                CLEAN_UP: begin
                    debug_command <= 0;
                    tx_word <= 0;
                    delay_counter <= 0;
                    address_out <= 0;
                end

                default: begin
                end
            endcase
        end

    end

    //debug comtroller state advance logic
    always_comb begin
        unique case(debug_state)
            DEBUG_OFF: begin
                debug_if.flash_write_en = 1'b0;
                if(debug_command == CORE_HALT) begin
                    next_debug_state = DEBUG_MENU;
                    halt = 1'b1;
                end
                else begin
                    next_debug_state = DEBUG_OFF;
                    halt = 1'b0;
                end
            end

            DEBUG_MENU: begin
                halt = 1'b1;
                debug_if.flash_write_en = 1'b0;
                unique case(debug_command)
                    RETURN_REG: begin
                        next_debug_state = DEBUG_RX;
                    end

                    RETURN_MEM: begin
                        next_debug_state = DEBUG_RX;
                    end

                    RETURN_PC: begin
                        next_debug_state = PROP_DELAY;
                    end

                    FLASH_WRITE: begin
                        next_debug_state = DEBUG_RX;
                    end

                    CORE_RESUME: begin
                        next_debug_state = CLEAN_UP;
                    end

                    default: begin
                        next_debug_state = DEBUG_MENU;
                    end
                endcase
            end

            DEBUG_RX: begin
                halt = 1'b1;
                if(debug_rx_done) begin
                    if(debug_command == FLASH_WRITE) begin
                        next_debug_state = BOOTLOAD;
                        debug_if.flash_write_en = 1'b1;
                    end
                    else begin
                        next_debug_state = PROP_DELAY;
                        debug_if.flash_write_en = 1'b0;
                    end
                end
                else begin
                    next_debug_state = DEBUG_RX;
                    debug_if.flash_write_en = 1'b0;
                end
            end

            PROP_DELAY: begin
                debug_if.flash_write_en = 1'b0;
                halt = 1'b1;
                if(delay_counter > 1) begin
                        next_debug_state = DEBUG_TX;
                end
                else begin
                        next_debug_state = PROP_DELAY;
                end
            end

            DEBUG_TX: begin
                halt = 1'b1;
                debug_if.flash_write_en = 1'b0;
                if(debug_tx_done)
                    next_debug_state = CLEAN_UP;
                else
                    next_debug_state = DEBUG_TX;
            end

            BOOTLOAD: begin
                halt = 1'b1;
                debug_if.flash_write_en = 1'b0;
                if(debug_if.flash_write_done) begin
                    next_debug_state = CLEAN_UP;
                end
                else begin
                    next_debug_state = BOOTLOAD;
                end
            end

            CLEAN_UP: begin
                halt = 1'b1;
                debug_if.flash_write_en = 1'b0;
                if(debug_command == CORE_RESUME) begin
                    next_debug_state = DEBUG_OFF;
                end
                else begin
                    next_debug_state = DEBUG_MENU;
                end
            end

            default begin
                next_debug_state = DEBUG_OFF;
                debug_if.flash_write_en = 1'b0;
                halt = 1'b0;
            end

        endcase
    end
    
    //debug rx state logic
    debug_trx_state_t debug_rx_state = TRX_IDLE;
    debug_trx_state_t next_debug_rx_state;
    logic [31:0] address_index = 0;
    logic [31:0] image_bytes = 0;
    logic [31:0] boot_image_size;
    logic size_received = 0;

    always_ff @(posedge debug_if.clk or negedge debug_if.rst_n) begin
        if(!debug_if.rst_n) begin
            debug_rx_state <= TRX_IDLE;
            rx_word <= 0;
            address_index <= 0;
            image_bytes <= 0;
            boot_image_size <= 0;
            size_received <= 0;
        end
        else begin
            debug_rx_state <= next_debug_rx_state;
            unique case(debug_rx_state)
                TRX_IDLE: begin
                    rx_word <= 0;
                    if(debug_state != DEBUG_RX) begin
                        size_received <= 0;
                        image_bytes <= 0;
                        address_index <= 0;
                    end
                end

                BYTE_0: begin
                    rx_word[31:24] <= uart_rec_if.byte_data;
                end

                BYTE_1: begin
                    rx_word[23:16] <= uart_rec_if.byte_data;
                end

                BYTE_2: begin
                    rx_word[15:8] <= uart_rec_if.byte_data;
                end

                BYTE_3: begin
                    rx_word[7:0] <= uart_rec_if.byte_data;
                end

                END_TRANSMISION: begin
                    if(debug_command == FLASH_WRITE) begin
                        if(!size_received) begin
                            image_bytes <= rx_word;
                            boot_image_size <= rx_word;
                            size_received <= 1'b1;
                            address_index <= 0;
                        end
                        else if(address_index + 4 < image_bytes) begin
                            address_index <= address_index + 4;
                        end
                        else begin
                            address_index <= 0;
                        end
                    end
                    else begin
                        address_index <= 0;
                        image_bytes <= 0;
                        size_received <= 0;
                    end
                end

                default begin
                    address_index <= 0;
                    image_bytes <= 0;
                    size_received <= 0;
                end
            endcase
        end
    end

    //read write output logic
    always_comb begin
        debug_if.write_data = 0;
        debug_if.write_en = 1'b0;
        debug_if.data_address = 0;
        unique case(debug_command)
            FLASH_WRITE: begin
                if(size_received && (debug_rx_state == END_TRANSMISION)) begin
                    debug_if.data_address = address_index;
                    debug_if.write_data = rx_word;
                    debug_if.write_en = 1'b1;
                end
                else if(debug_state == BOOTLOAD) begin
                    debug_if.write_data = boot_image_size;
                    debug_if.write_en = 1'b0;
                end
                else begin
                    debug_if.write_en = 1'b0;
                end
            end

            RETURN_REG,
            RETURN_MEM: begin
                debug_if.write_data = 0;
                debug_if.write_en = 1'b0;
                debug_if.data_address = address_out;
            end

            default: begin
                debug_if.write_data = 0;
                debug_if.write_en = 1'b0;
                debug_if.data_address = 0;
            end
        endcase
    end

    //rx state advance logic
    always_comb begin
        unique case(debug_rx_state)
            TRX_IDLE: begin
                debug_rx_done = 1'b0;
                if(debug_state == DEBUG_RX)
                    next_debug_rx_state = BYTE_0;
                else
                    next_debug_rx_state = TRX_IDLE;
            end

            BYTE_0: begin
                debug_rx_done = 1'b0;
                if(uart_rec_if.uart_tran_done)
                    next_debug_rx_state = BYTE_1;
                else
                    next_debug_rx_state = BYTE_0;
            end

            BYTE_1: begin
                debug_rx_done = 1'b0;
                if(uart_rec_if.uart_tran_done)
                    next_debug_rx_state = BYTE_2;
                else
                    next_debug_rx_state = BYTE_1;
            end

            BYTE_2: begin
                debug_rx_done = 1'b0;
                if(uart_rec_if.uart_tran_done)
                    next_debug_rx_state = BYTE_3;
                else
                    next_debug_rx_state = BYTE_2;
            end

            BYTE_3: begin
                debug_rx_done = 1'b0;
                if(uart_rec_if.uart_tran_done)
                    next_debug_rx_state = END_TRANSMISION;
                else
                    next_debug_rx_state = BYTE_3;
            end

            END_TRANSMISION: begin
                next_debug_rx_state = TRX_IDLE; 
                unique case(debug_command)
                    FLASH_WRITE: begin
                        if(size_received && (address_index + 4 >= image_bytes)) begin
                            debug_rx_done = 1'b1;
                        end
                        else begin
                            debug_rx_done = 1'b0;
                        end
                    end

                    default: begin
                        debug_rx_done = 1'b1;
                    end
                endcase
            end

            default: begin
                debug_rx_done = 1'b0;
                next_debug_rx_state = TRX_IDLE;
            end
        endcase
    end

    //debug tx state logic
    debug_trx_state_t debug_tx_state = TRX_IDLE;
    debug_trx_state_t next_debug_tx_state;

    always_ff @(posedge debug_if.clk or negedge debug_if.rst_n) begin
        if(!debug_if.rst_n) begin
            debug_tx_state <= TRX_IDLE;
        end
        else begin
            debug_tx_state <= next_debug_tx_state;
        end
    end

    //tx state advance logic
    always_comb begin
        unique case(debug_tx_state)
            TRX_IDLE: begin
                debug_tx_done = 1'b0;
                uart_trans_if.uart_tran_done = 0;
                if(debug_state == DEBUG_TX) begin
                    next_debug_tx_state = BYTE_0;
                end
                else begin
                    next_debug_tx_state = TRX_IDLE;
                end
            end

            BYTE_0: begin
                uart_trans_if.byte_data = tx_word[7:0];
                if(uart_trans_if.done) begin
                    next_debug_tx_state = BYTE_1;
                    uart_trans_if.uart_tran_done = 0;
                end
                else begin
                    next_debug_tx_state = BYTE_0;
                    uart_trans_if.uart_tran_done = 1;
                end
            end

            BYTE_1: begin
                uart_trans_if.byte_data = tx_word[15:8];
                if(uart_trans_if.done) begin
                    next_debug_tx_state = BYTE_2;
                    uart_trans_if.uart_tran_done = 0;
                end
                else begin
                    next_debug_tx_state = BYTE_1;
                    uart_trans_if.uart_tran_done = 1;
                end
            end

            BYTE_2: begin
                uart_trans_if.byte_data = tx_word[23:16];
                if(uart_trans_if.done) begin
                    next_debug_tx_state = BYTE_3;
                    uart_trans_if.uart_tran_done = 0;
                end
                else begin
                    next_debug_tx_state = BYTE_2;
                    uart_trans_if.uart_tran_done = 1;
                end
            end

            BYTE_3: begin
                uart_trans_if.byte_data = tx_word[31:24];
                if(uart_trans_if.done) begin
                    next_debug_tx_state = END_TRANSMISION;
                    uart_trans_if.uart_tran_done = 0;
                end
                else begin
                    next_debug_tx_state = BYTE_3;
                    uart_trans_if.uart_tran_done = 1;
                end
            end

            END_TRANSMISION: begin
                next_debug_tx_state = TRX_IDLE;
                uart_trans_if.uart_tran_done = 0;
                debug_tx_done = 1'b1;
            end

            default: begin
                next_debug_tx_state = TRX_IDLE;
                uart_trans_if.uart_tran_done = 0;
                debug_tx_done = 1'b0;
            end
        endcase
    end
endmodule