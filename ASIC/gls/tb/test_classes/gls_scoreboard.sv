/*
*   gls_scoreboard.sv checks that debug instructions executed correctly.
*
*   All observed values are 4-state. Any X/Z in what the chip returned or in the
*   probed expected value is an error (X === X would otherwise "match"), and all
*   comparisons use !== so an X never slips through as a pass.
*/

class gls_scoreboard;
    mailbox scoreboard_mailbox;
    int error_count = 0;
    int items_checked = 0;   //env waits on this before printing Total Errors

    //flags X/Z in a returned or expected value; returns 1 if it found any
    function bit check_known(string what, logic [31:0] value);
        if ($isunknown(value)) begin
            $error("%s contains X/Z: %h\n", what, value);
            error_count++;
            return 1;
        end
        return 0;
    endfunction

    //compares returned vs expected, flagging X/Z on either side first
    function void check_value(string what, logic [31:0] returned, logic [31:0] expected);
        bit unknown;
        unknown  = check_known({"Returned ", what}, returned);
        unknown |= check_known({"Expected ", what}, expected);
        if (!unknown && (returned !== expected)) begin
            $error("Returned %s value does not match (returned %h, expected %h)\n", what, returned, expected);
            error_count++;
        end
    endfunction

    task check_soc_output();
        forever begin
            soc_packet soc_item;
            scoreboard_mailbox.get(soc_item);

            //check to ensure proper behavior after instruction
            case(soc_item.debug_instruction)

                soc_packet::NOP: begin
                    if(soc_item.core_halt !== 1'b0) begin
                        $error("NOP caused core halt (core_halt = %b)\n", soc_item.core_halt);
                        error_count++;
                    end
                end

                soc_packet::CORE_HALT: begin
                    if(soc_item.core_halt !== 1'b1) begin
                        $error("Core did not halt (core_halt = %b)\n", soc_item.core_halt);
                        error_count++;
                    end
                end

                soc_packet::CORE_RESUME: begin
                    if(soc_item.core_halt !== 1'b0) begin
                        $error("Core did not resume execution (core_halt = %b)\n", soc_item.core_halt);
                        error_count++;
                    end
                end

                soc_packet::RETURN_REG: begin
                    check_value("register", soc_item.tx_line_return, soc_item.registers[soc_item.debug_address]);
                    $display("[SCOREBOARD] tx_line_return: %0h, debug_instruction: %0h, core halt: %0h, register_value: %0h\n",
                    soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.registers[soc_item.debug_address]);
                end

                soc_packet::RETURN_MEM: begin
                    case(soc_item.debug_address)
                        //4096-4104 is gpio pins memmap
                        4096: begin
                            check_value("gpio_dir", soc_item.tx_line_return, 32'(soc_item.gpio_dir));
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_dir: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_dir, soc_item.debug_address);
                        end

                        4100: begin
                            check_value("gpio_out", soc_item.tx_line_return, 32'(soc_item.gpio_out));
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_out: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_out, soc_item.debug_address);
                        end

                        4104: begin
                            check_value("gpio_in", soc_item.tx_line_return, 32'(soc_item.gpio_in));
                            $display("[SCOREBOARD] tx_line_return: %h, debug_instruction: %0h, core halt: %0h, gpio_in: %h, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.gpio_in, soc_item.debug_address);
                        end

                        default: begin
                            check_value("memory", soc_item.tx_line_return, soc_item.memory);
                            $display("[SCOREBOARD] tx_line_return: %d, debug_instruction: %0h, core halt: %0h, memory_value: %d, address: %d\n",
                            soc_item.tx_line_return, soc_item.debug_instruction, soc_item.core_halt, soc_item.memory, soc_item.debug_address);
                        end
                    endcase

                end
            endcase
            items_checked++;
        end
    endtask
endclass
