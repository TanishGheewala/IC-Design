/*
* soc_debug_packet.sv contains the test data structures for debug instructions and data recieved
*/
class soc_debug_packet;
    bit [7:0] debug_instruction;
    bit [31:0] tx_line_return;

    typedef enum bit [7:0] 
    {
        NOP          = 8'h00,
        CORE_HALT    = 8'h01,
        CORE_RESUME  = 8'h02,
        CORE_STEP    = 8'h03,
        RETURN_REG   = 8'h04,
        RETURN_MEM   = 8'h05
    } debug_instr_e;
endclass