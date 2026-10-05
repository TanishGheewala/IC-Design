This folders contains assembly code to test the debug controller in the soc_tb.sv. 
Loads all registers with values, will add memory loading to test as well.

    To compile from asm to readable .hx file:
        riscv64-unknown-elf-as -march=rv32i -mabi=ilp32  debug_test.s -o debug_test.o
        riscv64-unknown-elf-ld -m elf32lriscv -T debug_test_linker.ld debug_test.o -o debug_test.elf
        riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=4 debug_test.elf debug_test.hex