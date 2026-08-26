/*
*   Debug Controller: takes instructions from UART and decodes them into signals to control the core.
*/

//debug instructions
`define NOP                 4`00000
`define CORE_HALT            4'b0001
`define CORE_RESUME          4'b0010
`define CORE_STEP            4'b0011
`define RETURN_REG          4'b0100
`define RETURN_MEM          4'b0101

//debug_states
//DEBUG OFF
//DEBUG ON
//DATA RETURN
//CLEAN UP

module debug_controller(debug_interface.debug_dut debug_if);

    logic [31:0] core_signals;
    logic [31:0] data_return;
    logic data_return_ready;
    logic debug_state = DEBUG_OFF;

    always_ff @(posedge debug_if.clk) begin
        unique case(debug_state)
            DEBUG_OFF: begin
                case(debug_if.debug_instruction)
                    `CORE_HALT: begin
                        debug_if.core_halt <= 1'b1;
                        debug_state <= DEBUG_ON;
                    end 

                    default: begin
                        debug_if.core_halt <= 1'b0;
                        debug_state <= DEBUG_OFF;
                    end
                endcase
            end

            DEBUG_ON: begin
                case(debug_if.debug_instruction)
                    `RETURN_REG: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= RETURN_DATA;
                    end 

                    `RETURN_MEM: begin
                        debug_if.core_signals <= `RETURN_REG;
                        debug_state <= RETURN_DATA;
                    end 

                    default: begin
                        debug_state <= DEBUG_ON;
                    end
                endcase
            end

            

            defualt: cpu_halt = 1'b0;
        endcase
    end


endmodule