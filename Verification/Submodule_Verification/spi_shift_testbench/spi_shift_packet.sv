/*
* One packet is one frame: the mode, the byte the engine sends, the
* byte the slave model sends back, and what each side received.
*/
`include "../submodule_packet.sv"

class spi_shift_packet extends submodule_packet;

    //inputs
    rand bit       cpol; 
    rand bit       cpha; 
    rand bit       bit_order;   //1 = MSB first
    rand bit [7:0] tx_byte; 
    rand bit [7:0] slave_byte;  //wire order: [7] is the first bit on miso

    //outputs - 4-state so an X/Z from the DUT reaches the scoreboard
    logic [7:0] rx_byte;
    logic [7:0] mosi_seen;      //wire order, as captured by the slave model
    int         cycles;         //start edge to done

    function string mode_name();
        return $sformatf("mode %0d (cpol %0b cpha %0b), %s first",
                         {cpol, cpha}, cpol, cpha, bit_order ? "MSB" : "LSB");
    endfunction

    virtual function string convert_to_string();
        return $sformatf("[SPI_SHIFT TESTBENCH OUTPUT] %s, tx: 0x%02X, slave: 0x%02X | mosi_seen: 0x%02X, rx: 0x%02X, cycles: %0d",
                         mode_name(), tx_byte, slave_byte, mosi_seen, rx_byte, cycles);
    endfunction

endclass
