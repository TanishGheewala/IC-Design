/*
*   soc_debug_scoreboard.sv checks that debug instructions executed correctly.
*
*/

class soc_debug_scoreboard;
    mailbox scoreboard_mailbox;
    int error_count = 0;

    task check_soc_output();
        forever begin
            soc_packet soc_item;
            scoreboard_mailbox.get(soc_item);
            
            //check to ensure proper behavior after instruction
            case(soc_item.debug_instruction)

                soc_packet::NOP: begin
                    if(soc_item.core_halt) begin
                        $error("NOP caused core halt\n");
                        error_count++;
                    end
                end

                soc_packet::CORE_HALT: begin
                    if(!soc_item.core_halt) begin
                        $error("Core did not halt\n");
                        error_count++;
                    end
                end

                soc_packet::CORE_RESUME: begin
                    if(soc_item.core_halt) begin
                        $error("Core did not resume execution\n");
                        error_count++;
                    end
                end

                soc_packet::RETURN_REG: begin
                    if(soc_item.tx_line_return != soc_item.registers[soc_item.debug_address]) begin
                        $error("Returned register value does not match\n");
                        $display("[SCOREBOARD] tx_line_return: %0h, debug_instruction: %0h, core halt: %0h, register_value: %0h\n"
                        , soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.registers[soc_item.debug_address]);
                        error_count++;
                    end
                end

                soc_packet::RETURN_MEM: begin
                    if(soc_item.tx_line_return != soc_item.memory[soc_item.debug_address]) begin
                        $error("Returned memory value does not match\n");
                        $display("[SCOREBOARD] tx_line_return: %0h, debug_instruction: %0h, core halt: %0h, memory_value: %0h\n"
                        , soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.memory[soc_item.debug_address]);
                        error_count++;
                    end
                end
            endcase
        end
    endtask
endclass
