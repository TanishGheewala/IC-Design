/*
*   soc_debug_scoreboard.sv checks that debug instructions executed correctly.
*/

class soc_debug_scoreboard;
    mailbox scoreboard_mailbox;

    task check_soc_output();
        forever begin
            soc_packet soc_item;
            scoreboard_mailbox.get(soc_item);
            
            //logic to deduce proper result -- based on test code
            //use case statement for command -> calc correct result -> compare
        end
    endtask
endclass
