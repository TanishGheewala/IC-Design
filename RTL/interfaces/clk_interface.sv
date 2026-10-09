/*
* clk_interface used for testing modules
*/
`timescale 1ns/1ps
interface clk_interface();
    logic tb_clk;

    initial tb_clk <= 0;

    always #10 tb_clk = ~tb_clk;
endinterface
