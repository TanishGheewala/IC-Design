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
                        error_count++;
                    end
                    $display("[SCOREBOARD] tx_line_return: %0h, debug_instruction: %0h, core halt: %0h, register_value: %0h\n",
                    soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.registers[soc_item.debug_address]);
                end

                soc_packet::RETURN_MEM: begin
                    case(soc_item.debug_address)
                        //4096=4104 is gpio pins memmap
                        4096: begin
                            if(soc_item.tx_line_return != soc_item.gpio_dir) begin
                                $error("Returned gpio_dir value does not match\n");
                                error_count++;
                            end
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_dir: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_dir, soc_item.debug_address);
                        end

                        4100: begin
                            if(soc_item.tx_line_return != soc_item.gpio_out) begin
                                $error("Returned gpio_out value does not match\n");
                                error_count++;
                            end
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_out: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_out, soc_item.debug_address);
                        end

                        4104: begin
                            if(soc_item.tx_line_return != soc_item.gpio_in) begin
                                $error("Returned gpio_in value does not match\n");
                                error_count++;
                            end
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_in: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_in, soc_item.debug_address);
                        end

                        default: begin
                            if(soc_item.tx_line_return != soc_item.memory) begin
                                $error("Returned memory value does not match\n");
                                error_count++;
                            end
                            $display("[SCOREBOARD] tx_line_return: %d, debug_instruction: %0h, core halt: %0h, memory_value: %d, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.memory, soc_item.debug_address);
                        end
                    endcase

                end
            endcase
        end
    endtask
endclass
