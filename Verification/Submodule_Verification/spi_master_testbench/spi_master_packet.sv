/*
* One packet is one byte transfer done through the
* bus: CTRL write, TXDATA write, STATUS polling, RXDATA read.
*/
`include "../submodule_packet.sv"

class spi_master_packet extends submodule_packet;

    //inputs
    rand bit        cpol;
    rand bit        cpha;
    rand bit        bit_order;   //1 = MSB first
    rand bit [7:0]  tx_byte;
    rand bit [7:0]  slave_byte;  //wire order: [7] is the first bit on miso
    rand bit [23:0] junk;        //upper TXDATA bits, must be ignored
    rand bit        release_cs;  //clear CTRL.cs after this byte
    rand bit        disturb;     //write TXDATA/CTRL again mid-frame (ignored)

    //outputs - 4-state so an X/Z from the DUT reaches the scoreboard
    logic [7:0] rx_byte;         //read back through RXDATA
    logic [7:0] mosi_seen;       //wire order, as captured by the slave model

    constraint release_bias {
        release_cs dist {1 := 50, 0 := 50};
    }

    constraint disturb_bias {
        disturb dist {1 := 10, 0 := 90};
    }

    function string mode_name();
        return $sformatf("mode %0d (cpol %0b cpha %0b), %s first",
                         {cpol, cpha}, cpol, cpha, bit_order ? "MSB" : "LSB");
    endfunction

    virtual function string convert_to_string();
        return $sformatf("[SPI_MASTER TESTBENCH OUTPUT] %s, TXDATA: 0x%02X, slave: 0x%02X | mosi_seen: 0x%02X, RXDATA: 0x%02X",
                         mode_name(), tx_byte, slave_byte, mosi_seen, rx_byte);
    endfunction

endclass
