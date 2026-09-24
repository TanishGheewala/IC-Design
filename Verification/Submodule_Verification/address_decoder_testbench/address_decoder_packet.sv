/*
* address_decoder_packet contains the data structure used in testing the address decoder.
*/
`include "../submodule_packet.sv"

class address_decoder_packet extends submodule_packet;

    //inputs
    rand bit [9:0] addr;
    rand bit       mem_read;
    rand bit       mem_write;

    //outputs
    bit ram_sel;
    bit ram_we;
    bit io_sel;
    bit io_we;
    bit [9:0] io_addr;

    //loads/stores are always word-aligned
    constraint valid_addr {
        addr[1:0] == 2'b00;
    }

    //the core never asserts mem_read and mem_write on the same cycle
    constraint access_legal {
        !(mem_read && mem_write);
    }

    //most cycles are a real access rather than an idle bus
    constraint access_bias {
        mem_read  dist {1 := 45, 0 := 55};
        mem_write dist {1 := 45, 0 := 55};
    }

    virtual function string convert_to_string();
        return $sformatf("[ADDRESS DECODER TESTBENCH OUTPUT] addr: 0x%03X, mem_read: %0b, mem_write: %0b | ram_sel: %0b ram_we: %0b | io_sel: %0b io_we: %0b io_addr: 0x%03X",
                         addr, mem_read, mem_write, ram_sel, ram_we, io_sel, io_we, io_addr);
    endfunction

endclass
