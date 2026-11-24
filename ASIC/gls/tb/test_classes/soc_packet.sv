/*
* soc_debug_packet.sv contains the test data structures for debug instructions and data recieved
*/

`include "../../../../RTL/memory/macros.vh"

class soc_packet;   
    bit [7:0] debug_instruction;
    randc bit [31:0] debug_address;
    //observed values are 4-state (logic) so X/Z from the netlist reach the
    //scoreboard instead of being silently converted to 0
    logic [31:0] tx_line_return;
    logic [31:0] gpio_pins;
    logic core_halt;
    logic [31:0] registers [0:31];
    logic [31:0] memory;
    logic [9:0] gpio_dir;
    logic [9:0] gpio_out;
    logic [9:0] gpio_in;

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

    constraint c_registers { debug_address inside{[32'h0000:32'h0005]}; }
    constraint c_memory { debug_address inside {[32'h0000:32'h0014]}; 
                            debug_address % 4 == 0;}
endclass