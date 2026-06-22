`include "../submodule_packet.sv"

class rom_packet extends submodule_packet;

    rand bit [9:0]  addr;
    bit      [31:0] inst;

    constraint valid_addr {
        addr[1:0] == 2'b00;
        addr <= 10'h3FC; 
    }

    virtual function string convert_to_string();
        return $sformatf("[ROM TESTBENCH OUTPUT] addr: 0x%03X, inst: 0x%08X",
                         addr, inst);
    endfunction

endclass