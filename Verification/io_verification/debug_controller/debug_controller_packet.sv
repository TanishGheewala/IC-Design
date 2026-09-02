/* 
* debug_packet contains the data structure used in testing the debug controller
*
*/
`include "../../Submodule_Verification/submodule_packet.sv"

class debug_controller_packet extends submodule_packet;

    //inputs and outputs
    bit clk;
    bit tx;
    bit rx;
    bit core_halt;
    bit [31:0] core_signals;
    bit [31:0] data_return_in;
    bit [7:0] debug_state;
    bit [31:0] data_output;

    typedef enum bit [7:0] 
    {
        NOP          = 8'h00,
        CORE_HALT    = 8'h01,
        CORE_RESUME  = 8'h02,
        CORE_STEP    = 8'h03,
        RETURN_REG   = 8'h04,
        RETURN_MEM   = 8'h05,
        EXIT_DEBUG   = 8'h06 
    } debug_instr_e;

    typedef enum bit [7:0] 
    {
        DEBUG_OFF    = 8'h00,
        DEBUG_ON     = 8'h01,
        DATA_RETURN  = 8'h02,
        CLEAN_UP     = 8'h03
    } debug_state_e;


    //function override for alu
    virtual function string convert_to_string();
        return $sformatf("[DEBUG TESTBENCH OUTPUT] debug state: %0h, core signals: %0h, core halt: %0h, data output: %0h"
                            , debug_state, core_signals, core_halt, data_output);
    endfunction

endclass
