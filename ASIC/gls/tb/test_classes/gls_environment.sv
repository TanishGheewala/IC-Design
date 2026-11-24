/*
* soc_environment.sv tests the debug functionality when interacting with the core.
*/

class gls_environment;

    gls_driver driver;
    gls_monitor monitor;
    gls_scoreboard debug_scoreboard;
    gls_generator debug_generator;
    mailbox scoreboard_mailbox;
    mailbox monitor_mailbox;
    mailbox #(bit [7:0]) driver_mailbox;   //must match gls_driver / gls_generator

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
        debug_generator.core_probe_vif = core_probe_vif;
        debug_generator.soc_vif = soc_vif;

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

        //join_any returns when the generator finishes, but the monitor may still
        //be handing its last item (e.g. the final CORE_RESUME) to the scoreboard.
        //Wait until every item the monitor took has been checked, so the
        //Total Errors line printed by gls_test includes all checks.
        fork
            wait (debug_scoreboard.items_checked == monitor.items_received);
            begin
                #1ms;
                $error("Scoreboard did not drain: %0d of %0d items checked\n",
                       debug_scoreboard.items_checked, monitor.items_received);
                debug_scoreboard.error_count++;
            end
        join_any
        disable fork;
    endtask

endclass