/*
* soc_test.sv connects the input sequence with the evironment.
*/

class soc_test;
    //set up environment and mailbox for generator
    soc_environment env;

    function new();
        env = new();
    endfunction

    virtual task run();
        env.run_components();
        $display("[SCOREBOARD] Total Errors: %d\n", env.debug_scoreboard.error_count);
    endtask
endclass