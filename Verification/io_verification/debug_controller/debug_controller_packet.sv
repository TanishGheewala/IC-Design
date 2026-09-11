/* 
* debug_packet contains the data structure used in testing the debug controller
*
*/
`include "../../Submodule_Verification/submodule_packet.sv"

class debug_controller_packet extends submodule_packet;

    //inputs and outputs except clk, tx, rx
    bit core_halt;
    bit [7:0] core_signals;
    bit [31:0] data_return_in;
    bit [7:0] debug_state;
    bit [7:0] debug_command;
    bit [31:0] data_return_out;
    bit [31:0] data_address;

    typedef enum bit [7:0] 
    {
        NOP          = 8'h00,
        CORE_HALT    = 8'h01,
        CORE_RESUME  = 8'h02,
        CORE_STEP    = 8'h03,
        RETURN_REG   = 8'h04,
        RETURN_MEM   = 8'h05
    } debug_instr_e;


    //function override for alu
    virtual function string convert_to_string();
        return $sformatf("[DEBUG TESTBENCH OUTPUT]: core signals: %0h, core halt: %0h, data output: %0h, data address: %0h",
                            core_signals, core_halt, data_return_out);
    endfunction

endclass
