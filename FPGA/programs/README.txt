This folder contains the programs for demo on the fpga

    programs:
        - flash_led
        - 

    To compile from asm to readable .hx file:
        1. cd to directory for file u want to compile
        2. riscv64-unknown-elf-as -march=rv32i -mabi=ilp32  {program_name}.s -o {program_name}.o
        3. riscv64-unknown-elf-ld -m elf32lriscv -T {program_name}_linker.ld {program_name}.o -o {program_name}.elf
        4. riscv64-unknown-elf-objcopy -O verilog {program_name}.elf {program_name}.hex

    NOTE: the FPGA flash model (FPGA/rtl/flash_model_fpga.sv) is BYTE-wide (logic [7:0] mem),
    so the hex must be one byte per entry, little-endian (objcopy's default).
    Do NOT use --verilog-data-width=4: $readmemh would keep only the low byte of each word.
