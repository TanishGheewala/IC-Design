/*
*   flash_write: writes to flash lol, writes in pages to updata flash with new code recieved using debug controller
*       
*   LOOK AT SPI FLASH DOCUMENTATION SO I KNOW WHAT TO SEND
*   SHOULD SEND NUM OF BYTES SO IT KNOWS HOW MANY TO SEND
*/
module flash_write (flash_write_interface fl_wr_if);
    /*
        spi flash command pattern (some have quirks i need to look up)
        erase all -> page write until image size hit -> end
        
        FSM: IDLE -> ERASE -> PAGE_WRITE -> END CHECK -> END -> IDLE
    */
endmodule