/*
*   TAP controler: JTAG TAP controller
*/

`timescale 1ns/1ps

//JTAP TAP Controller States

`define TEST_LOGIC_RESET       4'b0000
`define RUN_TEST_IDLE          4'b0001
`define SELECT_DR_SCAN         4'b0010
`define CAPTURE_DR             4'b0011
`define SHIFT_DR               4'b0100
`define EXIT_1_DR              4'b0101
`define PAUSE_DR               4'b0110
`define EXIT_2_DR              4'b0111
`define UPDATE_DR              4'b1000
`define SELECT_IR_SCAN         4'b1001
`define CAPTURE_IR             4'b1010
`define SHIFT_IR               4'b1011
`define EXIT_1_IR              4'b1100
`define PAUSE_IR               4'b1101
`define EXIT_2_IR              4'b1110
`define UPDATE_IR              4'b1111


module tap_controller(tap_interface.tap_dut tap_if);

    logic tap_state;
    logic [4:0] instruction_reg;
    logic [4:0] data_reg;
    logic [4:0] ir_latch;
    logic [4:0] dr_latch;


    //JTAG state machine logic
    always_ff @(posedge tap_if.tck) begin

        unique case(tap_state) 
            `TEST_LOGIC_RESET: tap_state <= tap_if.tms ? `TEST_LOGIC_RESET : `RUN_TEST_IDLE;

            `RUN_TEST_IDLE: tap_state <= tap_if.tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;

            `SELECT_DR_SCAN: tap_state <= tap_if.tms ? `SELECT_IR_SCAN : `CAPTURE_DR;

            `CAPTURE_DR: tap_state <= tap_if.tms ? `EXIT_1_DR : `SHIFT_DR;

            `SHIFT_DR: tap_state <= tap_if.tms ? `EXIT_1_DR : `SHIFT_DR;

            `EXIT_1_DR: tap_state <= tap_if.tms ? `UPDATE_DR : `PAUSE_DR;

            `PAUSE_DR: tap_state <= tap_if.tms ? `EXIT_2_DR : `PAUSE_DR;

            `EXIT_2_DR: tap_state <= tap_if.tms ? `UPDATE_DR : `SHIFT_DR;

            `UPDATE_DR: tap_state <= tap_if.tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;

            `SELECT_IR_SCAN: tap_state <= tap_if.tms ? `TEST_LOGIC_RESET : `CAPTURE_IR;

            `CAPTURE_IR: tap_state <= tap_if.tms ? `EXIT_1_IR : `SHIFT_IR;

            `SHIFT_IR: tap_state <= tap_if.tms ? `EXIT_1_IR : `SHIFT_IR;

            `EXIT_1_IR: tap_state <= tap_if.tms ? `UPDATE_IR : `PAUSE_IR;

            `PAUSE_IR: tap_state <= tap_if.tms ? `EXIT_2_IR : `PAUSE_IR;

            `EXIT_2_IR: tap_state <= tap_if.tms ? `UPDATE_IR : `SHIFT_IR;

            `UPDATE_IR: tap_state <= tap_if.tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;

            default: tap_state <= `TEST_LOGIC_RESET;
        endcase
    end

    always_ff @(posedge tap_if.tck) begin
        
        unique case(tap_state)
            `CAPTURE_DR 
            default:
        endcase
    end





endmodule