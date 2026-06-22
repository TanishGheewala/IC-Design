`include "../submodule_packet.sv"

class ram_packet extends submodule_packet;
    rand bit [9:0]  addr;
    rand bit [31:0] data_in;
    rand bit        we;
    bit      [31:0] data_out;

    constraint valid_addr {
        addr[1:0] == 2'b00;
        addr <= 10'h3FC;
    }

    constraint write_bias {
        we dist {1 := 70, 0 := 30};
    }

    virtual function string convert_to_string();
        return $sformatf("[RAM TESTBENCH OUTPUT] addr: 0x%03X, we: %0b, data_in: 0x%08X, data_out: 0x%08X",
                         addr, we, data_in, data_out);
    endfunction

endclass