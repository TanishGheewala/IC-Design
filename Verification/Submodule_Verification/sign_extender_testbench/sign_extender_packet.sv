/* 
* sign_extender_packet contains the data structure used in testing the sign extender.
*
*/
`include "../submodule_packet.sv"

class sign_extender_packet extends submodule_packet;

    //inputs and outputs
    rand bit[6:0] se_opcode;
    rand bit [24:0] instruct_non_op;
    bit[31:0] instruct_data;
    bit[31:0] imme_out;
    //opcode constrains to ensure testing actual opcodes
    constraint valid_ops {
    se_opcode inside {
        7'b0110111, 7'b0010111, 7'b1101111, 7'b1100011, 7'b0100011,
        7'b0110011, 7'b1100111, 7'b0000011, 7'b0010011
    };
    }

    //function override for alu
    virtual function string convert_to_string();
        return $sformatf("[SIGN EXTENDER TESTBENCH OUTPUT] opcode: %0h, instruction: %0h, immediate extended: %0h "
                            , se_opcode, instruct_data, imme_out);
    endfunction

endclass