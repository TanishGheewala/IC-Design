/*
* the core_state_item will be used to check the state of the cpu with the state
* of the golden refrence model. It will contain all relevent cpu state info such as
* the register values.
*/

class core_state_item extends uvm_sequence_item;

    //uvm factory setup
    `uvm_object_utils(core_state_item);

    //RV32I architecture state
    bit [31:0] core_registers [5:0];
    bit [31:0] program_counter;
    bit [31:0] next_program_counter;

    //Internal signals to use for debugging (NOT FOR CHECKING WITH GOLDEN REFRENCE)
    // memory access info, reg access info, control flags


endclass