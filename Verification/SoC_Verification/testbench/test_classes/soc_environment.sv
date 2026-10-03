/*
* soc_environment.sv tests the debug functionality when interacting with the core.
*/

class soc_environment;

    soc_driver driver;
    soc_monitor monitor;
    soc_debug_scoreboard debug_scoreboard;
    soc_debug_generator debug_generator;
    mailbox scoreboard_mailbox;
    mailbox monitor_mailbox;
    mailbox driver_mailbox;

    virtual soc_interface soc_vif;
    virtual core_probe core_probe_vif;

    function new();
        driver = new;
        monitor = new;
        debug_scoreboard = new;
        debug_generator = new();
        scoreboard_mailbox = new();
        monitor_mailbox = new();
        driver_mailbox = new();
    endfunction

    virtual task run_components();
        //vifs
        driver.soc_vif = soc_vif;
        monitor.soc_vif = soc_vif;
        monitor.core_probe_vif = core_probe_vif;
        //mailboxes
        debug_generator.driver_mailbox = driver_mailbox;
        driver.driver_mailbox = driver_mailbox;
        debug_generator.monitor_mailbox = monitor_mailbox;
        monitor.monitor_mailbox = monitor_mailbox;
        monitor.scoreboard_mailbox = scoreboard_mailbox;
        debug_scoreboard.scoreboard_mailbox = scoreboard_mailbox;
        //events
        debug_generator.monitor_done = monitor.monitor_done;
        debug_generator.driver_done = driver.driver_done;
        monitor.driver_done = driver.driver_done;

        fork
            debug_scoreboard.check_soc_output();
            driver.send_debug_command();
            monitor.receive_soc_message();
            debug_generator.debug_instruction_sequence();
        join_any
    endtask

endclass