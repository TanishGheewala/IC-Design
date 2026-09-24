// Global Macros
// use `include "macros.vh"

`define ADDR_WIDTH 10 // 10-bit Address
`define DATA_WIDTH 32 // 32-bit Word Size
`define MEM_DEPTH 256 // ROM depth: 256 words * 4 bytes = 1024 bytes (full address space)

// The data address space (`ADDR_WIDTH bits, byte-addressed) is split by
// address_decoder.sv on the top bit (addr[9]):
//   addr[9] = 0 -> RAM window : 0x000-0x1FF (512 B, 128 words)
//   addr[9] = 1 -> I/O window : 0x200-0x3FF (512 B, memory-mapped peripherals)
`define RAM_DEPTH 128 // RAM depth: 128 words * 4 bytes = 512 bytes (half the data address space)
