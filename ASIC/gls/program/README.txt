These folders contains assembly code to test the gate level netlist post innovus. 
loops first 5 memory locations, then loads 5 registers, then sets gpio to input, then infinite loop.

    To compile from asm to readable .hx file:
        riscv64-unknown-elf-as -march=rv32i -mabi=ilp32  gls_test.s -o gls_test.o
        riscv64-unknown-elf-ld -m elf32lriscv -T gls_test_linker.ld gls_test.o -o gls_test.elf
        riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=4 gls_test.elf gls_test.hex