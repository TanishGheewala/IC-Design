/*
* soc_test.sv connects the input sequence with the evironment.
*/

class gls_test;
    //set up environment and mailbox for generator
    gls_environment env;

    function new();
        env = new();
    endfunction

    virtual task run();
        env.run_components();
        $display("[SCOREBOARD] Total Errors: %d\n", env.debug_scoreboard.error_count);
    endtask
endclass