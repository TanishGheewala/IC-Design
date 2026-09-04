/*
*   Debug Controller: takes instructions from UART and decodes them into signals to control the core.
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
`define DEBUG_OFF           2'b00
`define DEBUG_ON            2'b01
`define DATA_RETURN         2'b10
`define CLEAN_UP            2'b11

module debug_controller(debug_interface.debug_dut debug_if);

    logic [31:0] core_signals;
    logic [31:0] data_return;
    logic [7:0] debug_instruction = `NOP;
    logic data_return_ready;    
    logic [1:0] debug_state = `DEBUG_OFF;
    //craete staging register so only fully transmitted command is shown to to debug controller

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
        end else begin
            debug_instruction <= 0;
        end
    end

    //uart transmission to controller connection
    always_ff@(posedge debug_if.clk) begin
        if(data_return_ready == 1'b1) begin
            uart_trans_if.byte_data <= data_return;
            uart_trans_if.uart_tran_done <= 1'b1;
        end else begin
            uart_trans_if.byte_data <= 0;
            uart_trans_if.uart_tran_done <= 1'b0;
        end
    end

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
                data_return_ready = 1'b0;

                case(debug_instruction)
                    `RETURN_REG: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= `DATA_RETURN;
                    end 

                    `RETURN_MEM: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= `DATA_RETURN;
                    end 

                    `CORE_RESUME: begin
                        debug_if.core_signals <= `NOP;
                        debug_state <= `CLEAN_UP;
                    end

                    default: begin
                        debug_state <= `DEBUG_ON;
                    end
                endcase
            end

            //core returns data to debug controller based on command entered\
            //loop backk to DEBUG ON
            `DATA_RETURN: begin
                data_return <= debug_if.data_return_in;
                debug_state <= `DEBUG_ON;
                data_return_ready <= 1'b1;
            end
            
            //debug_controller gives control back to core
            //clears debug controller registers
            `CLEAN_UP: begin
                debug_if.core_signals <= 0;
                debug_if.core_halt <= 1'b0;
                debug_state <= `DEBUG_OFF;
            end

        endcase
    end


endmodule