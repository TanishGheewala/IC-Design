/* 
* branch_unit_packet contains the data structure used in testing the branch unit.
*
*/
`include "../submodule_packet.sv"

class branch_unit_packet extends submodule_packet;

    //inputs and outputs
    rand bit branch_flag;
    rand bit[3:0] branch_opcode;
    rand bit[31:0] input_0;
    rand bit[31:0] input_1;
    bit output_flag;

    //opcode constrains to ensure testing actual opcodes for branches
    constraint valid_ops {
    branch_opcode inside {
        3'b000, 3'b001, 3'b100, 3'b101, 3'b110,
        3'b111, 3'b010
    };
    }

    //function override for branch unit
    virtual function string convert_to_string();
        return $sformatf("[ALU TESTBENCH OUTPUT]  brach flag: %0h, opcode: %0h, input 0: %0h, input 1: %0h, output: %0h "
                            ,branch_flag, branch_opcode, input_0, input_1, output_flag);
    endfunction

endclass
