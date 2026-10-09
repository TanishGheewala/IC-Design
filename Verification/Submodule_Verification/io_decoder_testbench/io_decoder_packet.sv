/*
* io_decoder_packet contains the data structure used in testing the I/O window sub-decoder.
*/
`include "../submodule_packet.sv"

class io_decoder_packet extends submodule_packet;

    //sized for the largest configuration under test; only the first
    //num_periphs entries are meaningful for a given DUT
    localparam int MAX_PERIPHS = 16;

    //inputs (what address_decoder and the core hand to io_decoder)
    rand bit [9:0]  io_addr;
    rand bit        io_sel;
    rand bit        io_we;
    rand bit [31:0] wdata;

    //value each peripheral model drives back on its rdata
    rand bit [31:0] periph_rdata [MAX_PERIPHS];

    //outputs - 4-state so an X/Z from the DUT reaches the scoreboard instead
    //of being silently converted to 0
    int          num_periphs;
    logic        sel     [MAX_PERIPHS];
    logic        we      [MAX_PERIPHS];
    logic [9:0]  addr    [MAX_PERIPHS];   //local offset, zero-extended
    logic [31:0] p_wdata [MAX_PERIPHS];
    logic [31:0] rdata;

    //word-aligned, and address_decoder always clears the I/O select bit
    constraint valid_addr {
        io_addr[1:0] == 2'b00;
        io_addr[9]   == 1'b0;
    }

    //address_decoder only raises io_we on an I/O access
    constraint legal_strobes {
        io_we -> io_sel;
    }

    //most cycles are a real I/O access rather than an idle bus
    constraint access_bias {
        io_sel dist {1 := 80, 0 := 20};
    }

    virtual function string convert_to_string();
        string sel_s = "";
        string we_s  = "";
        string local_s = "-";

        for (int k = num_periphs - 1; k >= 0; k--) begin
            sel_s = {sel_s, sel[k] ? "1" : "0"};
            we_s  = {we_s,  we[k]  ? "1" : "0"};
            if (sel[k]) local_s = $sformatf("0x%02X (slot %0d)", addr[k], k);
        end

        return $sformatf("[IO DECODER TESTBENCH OUTPUT] io_addr: 0x%03X, io_sel: %0b, io_we: %0b, wdata: 0x%08X | sel[%0d:0]: %s we[%0d:0]: %s local_addr: %s | rdata: 0x%08X",
                         io_addr, io_sel, io_we, wdata,
                         num_periphs - 1, sel_s, num_periphs - 1, we_s, local_s, rdata);
    endfunction

endclass
