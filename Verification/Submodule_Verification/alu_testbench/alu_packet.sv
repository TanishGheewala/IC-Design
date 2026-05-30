/* 
* alu_packet contains the data structure used in testing the alu.
*
*/
`include "../submodule_packet.sv"

class alu_packet extends submodule_packet;

    //inputs and outputs
    rand bit[5:0] alu_opcode;
    rand bit[31:0] in_data_0;
    rand bit[31:0] in_data_1;
    bit[31:0] out_data;

    //opcode constrains to ensure testing actual opcodes
    constraint valid_ops {
    alu_opcode inside {
        6'b011001, 6'b011010, 6'b011011, 6'b011100, 6'b011101,
        6'b011110, 6'b011111, 6'b100000, 6'b100001, 6'b100010,
        6'b100011, 6'b100100
    };
    }

    //function override for alu
    virtual function string convert_to_string();
        return $sformatf("[ALU TESTBENCH OUTPUT] opcode: %0h, input 0: %0h, input 1: %0h, output: %0h "
                            , alu_opcode, in_data_0, in_data_1, out_data);
    endfunction

endclass