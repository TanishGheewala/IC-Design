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
    bit [31:0] memory [0:`MEM_DEPTH-1];

    typedef enum bit [7:0] 
    {
        NOP          = 8'h00,
        CORE_HALT    = 8'h01,
        CORE_RESUME  = 8'h02,
        CORE_STEP    = 8'h03,
        RETURN_REG   = 8'h04,
        RETURN_MEM   = 8'h05
    } debug_instr_e;

    constraint c_registers { debug_address inside{[32'h0000:32'h0010]}; }
    constraint c_memory { debug_address inside {[32'h0000:`MEM_DEPTH]}; }
endclass