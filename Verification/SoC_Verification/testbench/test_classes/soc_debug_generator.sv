/*
* soc_debug_generator.sv designates an input sequence for the debug controller.
*/
`include "../../../../RTL/memory/macros.vh"

class soc_debug_generator;

    //generator variables
    mailbox driver_mailbox;
    mailbox monitor_mailbox;
    event driver_done;
    event monitor_done;
    int num_registers = 32;
    int num_memory = 10;

    function new();
        driver_mailbox = new();
        monitor_mailbox = new();
    endfunction
    
    //tests all registers and memory values coming through debug controller
    virtual task debug_instruction_sequence();
        soc_packet soc_item;

        $display ("T=%0t [Test] Starting Sequence ...", $time);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);
        
        //loops through all registers and checks debug controller returns correct value for each
        @(driver_done);
        for(int i = 0; i < num_registers; i++) begin
            soc_item = new;
            //turns on register contraint for debug address
            soc_item.c_registers.constraint_mode(1);
            soc_item.c_memory.constraint_mode(0);
            soc_item.randomize();
            soc_item.debug_instruction = soc_packet::RETURN_REG;
            driver_mailbox.put(soc_item.debug_instruction);
            monitor_mailbox.put(soc_item);

            //sends address in sections over uart
            for(int j = 0; j < 4; j++) begin
                @(driver_done);
                case(j)
                    0:  driver_mailbox.put(soc_item.debug_address[31:24]);
                    1:  driver_mailbox.put(soc_item.debug_address[23:16]);
                    2:  driver_mailbox.put(soc_item.debug_address[15:8]);
                    3:  driver_mailbox.put(soc_item.debug_address[7:0]);
                endcase
            end
            @(monitor_done);
        end

        //resumes core and ends debug check
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item.debug_instruction);
        monitor_mailbox.put(soc_item);

        @(driver_done);
    endtask
    
endclass