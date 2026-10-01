/*
* soc_test.sv connects the input sequence with the evironment.
*/

class soc_test;

    //set up environment and mailbox for generator
    soc_environment env;
    mailbox driver_mailbox;

    function new();
        driver_mailbox = new();
        env = new();
    endfunction

    virtual task run();
        env.driver.driver_mailbox = driver_mailbox;

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

        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_HALT;
        driver_mailbox.put(soc_item);

        soc_item = new;
        soc_item.debug_instruction = soc_packet::CORE_RESUME;
        driver_mailbox.put(soc_item);

        soc_item = new;
        soc_item.debug_instruction = soc_packet::NOP;
        driver_mailbox.put(soc_item);

    endtask
    
endclass