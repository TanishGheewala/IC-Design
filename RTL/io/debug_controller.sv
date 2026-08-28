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

//debug_states
`define DEBUG_OFF           2'b00
`define DEBUG_ON            2'b01
`define DATA_RETURN         2'b10
`define CLEAN_UP            2'b11

module debug_controller(debug_interface.debug_dut debug_if);

    logic [31:0] core_signals;
    logic [31:0] data_return;
    logic data_return_ready;
    logic [1:0] debug_state = `DEBUG_OFF;

    //craete staging register so only fully transmitted command is shown to to debug controller

    always_ff @(posedge debug_if.clk) begin
        unique case(debug_state)

            //core runs normally
            `DEBUG_OFF: begin
                case(debug_if.debug_instruction)
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
                case(debug_if.debug_instruction)
                    `RETURN_REG: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= `DATA_RETURN;
                    end 

                    `RETURN_MEM: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= `DATA_RETURN;
                    end 

                    //state for exting DEBUG ON

                    default: begin
                        debug_state <= `DEBUG_ON;
                    end
                endcase
            end

            //core returns data to debug controller based on command entered
            `DATA_RETURN: begin
                debug_if.data_return_out <= debug_if.data_return_in;
                debug_state <= `CLEAN_UP;

                //add delay for UART transmission back to computer
                //if transmission not done stay on state
                //if done go back to debug_on
                //loop backk to DEBUG ON
            end
            
            //debug_controller gives control back to core
            //clears debug controller registers
            `CLEAN_UP: begin
                debug_if.data_return_out <= 0;
                debug_if.core_signals <= 0;
                debug_if.core_halt <= 1'b0;


            end

        endcase
    end


endmodule