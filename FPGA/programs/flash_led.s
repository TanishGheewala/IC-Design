#placeholder for flash led.s

.global _start
.section .text
_start:

    addi x20, zero, 0
    addi x21, zero, 20
_mem_loop:                  #fill memory with values
    sw x20, 0(x20)
    addi x20, x20, 4
    blt x20, x21, _mem_loop

_fill_registers:            #load register loop
    addi x1, zero, 1
    addi x2, zero, 2
    addi x3, zero, 3
    addi x4, zero, 4
    addi x5, zero, 5

    li x20, 0x00001000
    li x21, 0x00000000
    sw x21, 0(x20)

_loop:                      #infinite while loop to keep program running
    j _loop