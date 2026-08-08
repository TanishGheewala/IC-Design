`include "../submodule_packet.sv"

class register_file_packet extends submodule_packet;

    rand bit [4:0]  rs1_addr;
    rand bit [4:0]  rs2_addr;
    rand bit [4:0]  rd_addr;
    rand bit [31:0] write_data;
    rand bit        reg_write;

    bit [31:0] rs1_data;
    bit [31:0] rs2_data;

    constraint write_bias {
        reg_write dist {1 := 70, 0 := 30};
    }

    virtual function string convert_to_string();
        return $sformatf("[REGISTER FILE TESTBENCH OUTPUT] rs1_addr: %0d, rs2_addr: %0d, rd_addr: %0d, reg_write: %0b, write_data: %0h, rs1_data: %0h, rs2_data: %0h",
                         rs1_addr, rs2_addr, rd_addr, reg_write, write_data,
                         rs1_data, rs2_data);
    endfunction

endclass