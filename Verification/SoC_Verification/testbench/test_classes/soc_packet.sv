/*
* soc_debug_packet.sv contains the test data structures for debug instructions and data recieved
*/

`include "../../../../RTL/memory/macros.vh"

class soc_packet;   
    bit [7:0] debug_instruction;
    randc bit [31:0] debug_address;
    bit [31:0] tx_line_return;
    bit [31:0] gpio_pins;
    bit core_halt;
    bit [31:0] registers [0:31];
    bit [31:0] memory;
    bit [9:0] gpio_dir;
    bit [9:0] gpio_out;
    bit [9:0] gpio_in;

    //commands user can input to mircrocontroller
    typedef enum logic [7:0] {
        NOP,
        CORE_HALT,
        RETURN_REG,
        RETURN_MEM,
        RETURN_PC,
        FLASH_WRITE,
        CORE_RESUME = 8'hff
    }debug_command_t;

    constraint c_registers { debug_address inside{[32'h0000:32'h0010]}; }
    constraint c_memory { debug_address inside {[32'h0000:32'h0040]}; 
                            debug_address % 4 == 0;}
endclass