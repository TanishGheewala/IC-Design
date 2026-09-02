/*
*   debug_controller driver drives DEBUG commands through UART
*/
class debug_controller_driver;
  virtual debug_interface debug_vif;
  event driver_done;
  mailbox driver_mailbox;

  task run();
    @ (posedge vif.clk);
  endtask
endclass