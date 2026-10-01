/*
* soc_environment.sv tests the debug functionality when interacting with the core.
*/

class soc_environment;

    soc_driver driver;
    soc_monitor monitor;
    soc_debug_scoreboard debug_scoreboard;
    mailbox scoreboard_mailbox;

    virtual soc_interface soc_vif;

    function new();
        driver = new;
        monitor = new;
        debug_scoreboard = new;
        scoreboard_mailbox = new();
    endfunction

    virtual task run_components();
        driver.soc_vif = soc_vif;
        monitor.soc_vif = soc_vif;
        monitor.scoreboard_mailbox = scoreboard_mailbox;
        debug_scoreboard.scoreboard_mailbox = scoreboard_mailbox;

        fork
            debug_scoreboard.check_soc_output();
            driver.send_debug_command();
            monitor.receive_soc_message();
        join_any
    endtask

endclass