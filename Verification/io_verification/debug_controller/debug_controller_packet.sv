/* 
* debug_packet contains the data structure used in testing the debug controller
*
*/
`include "../../Submodule_Verification/submodule_packet.sv"

class debug_controller_packet extends submodule_packet;

    //inputs and outputs except clk, tx, rx
    bit core_halt;
    bit [7:0] command;
    bit [31:0] core_data;

    bit write_en;
    bit [31:0] write_data;
    bit [31:0] data_address;

    bit bootl_done;

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


    //function override for alu
    virtual function string convert_to_string();
        return $sformatf("[DEBUG TESTBENCH OUTPUT]: command: %0h, core_data: %0h, write_en: %0h, wrote_data: %0h, data_address: %0h, core_halt: %0h, bootl_done: %0h",
                            command, core_data, write_en, write_data, data_address, core_halt, bootl_done);
    endfunction

endclass
