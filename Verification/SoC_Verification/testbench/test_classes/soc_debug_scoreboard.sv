/*
*   soc_debug_scoreboard.sv checks that debug instructions executed correctly.
*/

class soc_debug_scoreboard;
    mailbox scoreboard_mailbox;

    task check_soc_output();
        forever begin
            soc_packet soc_item;
            scoreboard_mailbox.get(soc_item);
            
            case(soc_item.debug_instruction)

                soc_packet::NOP: begin
                    if(!(soc_item.tx_line_return == 0))
                        $error("NOP produced data output");
                end

                soc_packet::CORE_HALT: begin
                    if(!soc_item.core_halt)
                        $error("Core did not halt");
                end

                soc_packet::CORE_RESUME: begin
                    if(soc_item.core_halt)
                        $error("Core did not resume execution");
                end

                soc_packet::RETURN_REG: begin
                    if(soc_item.tx_line_return != soc_item.registers[soc_item.debug_address]);
                        $error("Returned register value does not match");
                end

                soc_packet::RETURN_MEM: begin
                    if(soc_item.tx_line_return != soc_item.memory[soc_item.debug_address]);
                        $error("Returned memory value does not match");
                end
            endcase
        end
    endtask
endclass
