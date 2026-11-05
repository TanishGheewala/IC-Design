/*
* bootloader_packet: one packet = one complete boot.
*
* How a packet is used by bootloader_test:
*   1. The test creates a packet and randomizes it. That fills image[] with
*      the bytes the fake flash will hold for this boot.
*   2. The test resets the DUT. The flash model (spi_slave_model) answers the
*      bootloader's READ: the first 4 bytes it receives are recorded in
*      cmd_seen / addr_seen, and for every byte after that it sends back
*      flash_byte(addr), starting at the address the bootloader asked for.
*   3. While the boot runs, the test counts SRAM writes into write_count.
*   4. After boot_done, the test reads every word back out of the real
*      instruction SRAM into sram_words[], and compares each one to
*      expected_word(). Nothing else is copied: the packet is the expected
*      data, so whatever the SRAM holds has to match it.
*
* fill_index_pattern() gives a fixed, readable pattern instead (byte i =
* i*37+11)
*
* IMAGE_BYTES and FLASH_BASE_ADDR are bootloader parameters, so they can't
* change between packets; the test passes the same values into new().
*/
`include "../submodule_packet.sv"

class bootloader_packet extends submodule_packet;

    //configuration, matches the DUT parameters
    int        n_bytes;     //IMAGE_BYTES
    bit [23:0] base_addr;   //FLASH_BASE_ADDR

    //inputs: flash image the bootloader should copy
    rand bit [7:0] image[];

    //outputs - 4-state so an X from the DUT or SRAM reaches the scoreboard
    logic [7:0]  cmd_seen;       //first byte on mosi, should be 0x03
    logic [23:0] addr_seen;      //next 3 bytes on mosi, should be base_addr
    int          write_count;    //number of mem_we pulses, should be n_bytes
    logic [31:0] sram_words[];   //SRAM contents read back after boot_done

    constraint image_size {
        image.size() == n_bytes;
    }

    function new(int n_bytes, bit [23:0] base_addr);
        this.n_bytes   = n_bytes;
        this.base_addr = base_addr;
    endfunction

    //directed alternative to randomize(): byte i = i*37+11, every byte differs from its neighbours
    function void fill_index_pattern();
        image = new[n_bytes];
        foreach (image[i])
            image[i] = 8'(i * 37 + 11);
    endfunction

    //number of SRAM words the image touches, rounded up for a partial last word
    function int n_words();
        return (n_bytes + 3) / 4;
    endfunction

    //what the flash holds at a 24-bit address: the image at base_addr,
    //erased flash (0xFF) everywhere else
    function bit [7:0] flash_byte(bit [23:0] addr);
        int offset = int'(addr) - int'(base_addr);
        if (offset >= 0 && offset < n_bytes)
            return image[offset];
        return 8'hFF;
    endfunction

    //what SRAM word w must hold after boot. Flash byte 4w goes in bits [7:0]
    //(little-endian). Lanes past the end of the image were never written, so
    //they stay X (the SRAM macro powers up as X); comparing with !== then
    //also catches the bootloader writing one byte too many.
    function logic [31:0] expected_word(int w);
        logic [31:0] word = 'x;
        for (int lane = 0; lane < 4; lane++)
            if (4*w + lane < n_bytes)
                word[8*lane +: 8] = image[4*w + lane];
        return word;
    endfunction

    virtual function string convert_to_string();
        return $sformatf("[BOOTLOADER TESTBENCH OUTPUT] %0d bytes from flash 0x%06X | cmd_seen: 0x%02X, addr_seen: 0x%06X, writes: %0d, word0: 0x%08X (expected 0x%08X)",
                         n_bytes, base_addr, cmd_seen, addr_seen, write_count,
                         (sram_words.size() > 0) ? sram_words[0] : 32'hx, expected_word(0));
    endfunction

endclass
