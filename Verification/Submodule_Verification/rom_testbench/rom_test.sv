`timescale 1ns/1ps
 
module rom_test;
 
    logic [9:0] addr;
    logic [31:0] inst;
 
    instruction_memory dut (
        .addr(addr),
        .inst(inst)
    );
 
    initial begin
        $readmemh("test_program.hex", dut.rom);
        addr = 0; #10;
        $display("addr=0x%03X inst=0x%08X", addr, inst);
        addr = 4; #10;
        $display("addr=0x%03X inst=0x%08X", addr, inst);
        addr = 8; #10;
        $display("addr=0x%03X inst=0x%08X", addr, inst);
        $display("ROM test done");
        $finish;
    end
 
endmodule
