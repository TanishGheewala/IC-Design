/*
* gpio_packet contains the data structure used in testing the GPIO peripheral.
* One packet is one clock cycle: the bus access and pin levels applied that
* cycle, and the outputs observed before the next clock edge.
*/
`include "../submodule_packet.sv"

class gpio_packet extends submodule_packet;

    //inputs
    rand bit        rst_n;
    rand bit [3:0]  reg_idx;   //word index in the slot; addr is derived from it
    bit      [5:0]  addr;      //byte offset within the GPIO slot
    rand bit        sel;
    rand bit        we;
    rand bit [31:0] wdata;
    rand bit [9:0]  gpio_in;

    //outputs - 4-state so an X/Z from the DUT reaches the scoreboard instead
    //of being silently converted to 0
    logic [31:0] rdata;
    logic [9:0]  gpio_out;
    logic [9:0]  gpio_oe;

    //mostly the three real registers (DIR/OUT/IN), sometimes an unmapped
    //offset so ignored writes and zero reads get exercised
    constraint reg_bias {
        reg_idx dist {0 := 30, 1 := 30, 2 := 25, [3:15] :/ 15};
    }

    //io_decoder only raises we on a selected access
    constraint legal_strobes {
        we -> sel;
    }

    constraint access_bias {
        sel dist {1 := 80, 0 := 20};
    }

    //occasional mid-run reset
    constraint reset_bias {
        rst_n dist {1 := 98, 0 := 2};
    }

    function void post_randomize();
        addr = {reg_idx, 2'b00};
    endfunction

    function string reg_name();
        case (addr)
            6'h00:   return "DIR";
            6'h04:   return "OUT";
            6'h08:   return "IN";
            default: return "unmapped";
        endcase
    endfunction

    virtual function string convert_to_string();
        return $sformatf("[GPIO TESTBENCH OUTPUT] rst_n: %0b, addr: 0x%02X (%s), sel: %0b, we: %0b, wdata: 0x%08X, gpio_in: 0x%03X | rdata: 0x%08X, gpio_oe: 0x%03X, gpio_out: 0x%03X",
                         rst_n, addr, reg_name(), sel, we, wdata, gpio_in, rdata, gpio_oe, gpio_out);
    endfunction

endclass
