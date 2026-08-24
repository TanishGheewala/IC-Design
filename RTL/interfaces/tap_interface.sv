/*
* Interface for JTAG TAP controller module. Defines all I/O ports.
*/
interface tap_interface();

    //test clock
    logic tck;
    //test mode select
    logic tms;
    //test data in
    logic tdi;
    //test data out
    logic tdo;
    
    //dut setup
    modport tap_dut
    (
        input tck,
        input tms,
        input tdi,
        output tdo
    );

endinterface
