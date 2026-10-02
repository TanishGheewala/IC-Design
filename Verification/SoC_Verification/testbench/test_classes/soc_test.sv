/*
* soc_test.sv connects the input sequence with the evironment.
*/

class soc_test;

    //set up environment and mailbox for generator
    soc_environment env;
    mailbox driver_mailbox;
    event driver_done;
    event monitor_done;

    function new();
        driver_mailbox = new();
        env = new();
    endfunction

    virtual task run();
        env.driver.driver_mailbox = driver_mailbox;
        env.driver.driver_done = driver_done;
        env.monitor.monitor_done = monitor_done;

        fork
            env.run_components();
        join_none

        debug_instruction_sequence();
    endtask
    
    //basic test sequence to verify test functionality
    virtual task debug_instruction_sequence();
        soc_packet soc_item;

        $display ("T=%0t [Test] Starting Sequence ...", $time);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item);
        $display("Instruction 1");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item);
        $display("Instruction 2");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::RETURN_REG;
        driver_mailbox.put(soc_item);
        $display("Instruction 3");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = 8'h00;
        driver_mailbox.put(soc_item);
        $display("Instruction 4");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = 8'h00;
        driver_mailbox.put(soc_item);
        $display("Instruction 5");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = 8'h00;
        driver_mailbox.put(soc_item);
        $display("Instruction 6");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = 8'h01;
        driver_mailbox.put(soc_item);
        $display("Instruction 7");

        @(driver_done);
        @(monitor_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item);
        $display("Instruction 8");

        @(driver_done);
        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item);
        $display("Instruction 9");

        @(driver_done);
    endtask
    
endclass