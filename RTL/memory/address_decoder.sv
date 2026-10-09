// address_decoder.sv - Data address space decoder (RAM vs. memory-mapped I/O)
//
// Sits between the ALU and the
// physical devices (data_memory, and later the I/O peripherals). Iit only looks at the address and read/write
// strobes coming from the core each cycle, and produces one select + one
// write-enable per device, so exactly the right device responds.
//
// addr[IO_SEL_BIT] selects the window: 0 -> RAM, 1 -> I/O. 

`timescale 1ns/1ps

module address_decoder #(
    // Width of the byte address bus. 10 bits -> 1024-byte data address space.
    parameter int ADDR_WIDTH = 10,

    //   addr[IO_SEL_BIT] = 0 -> lower half is RAM
    //   addr[IO_SEL_BIT] = 1 -> upper half is the I/O window
    parameter int IO_SEL_BIT = ADDR_WIDTH - 1,

    // Escape hatch: when 0, the RAM/I/O split is disabled and the entire
    // address space behaves as flat RAM (io_sel never asserts)
    parameter bit ENABLE_IO = 1'b1
)( address_decoder_interface.ad_dut dec_if);

    always_comb begin

        // ENABLE_IO is a parameter (fixed at elaboration time, not a runtime
        // signal), so this if/else doesn't synthesize into a real mux - only
        // one branch ever exists in the built hardware.
        if (ENABLE_IO) begin
            // ram_sel: the address's top bit is 0 (falls in the RAM half)
            // AND the core actually wants to read or write this cycle.
            dec_if.ram_sel = ~dec_if.addr[IO_SEL_BIT] & (dec_if.mem_read | dec_if.mem_write);

            // io_sel: the mirror-image condition - top bit is 1 (falls in
            // the I/O half) AND an access is requested. ram_sel and io_sel
            // are mutually exclusive; both are 0 on a cycle with no access.
            dec_if.io_sel  =  dec_if.addr[IO_SEL_BIT] & (dec_if.mem_read | dec_if.mem_write);
        end else begin
            // I/O disabled: every access goes to RAM regardless of address,
            
            dec_if.ram_sel = dec_if.mem_read | dec_if.mem_write;
            dec_if.io_sel  = 1'b0;
        end

        dec_if.ram_we = dec_if.ram_sel & dec_if.mem_write;
        dec_if.io_we  = dec_if.io_sel  & dec_if.mem_write;

       
        // select bit turns a full address like 0x204 into offset 0x004,
        // which is what gets handed to the I/O peripherals via io_addr.
        dec_if.io_addr = dec_if.addr & ~(1 << IO_SEL_BIT);
    end

endmodule
