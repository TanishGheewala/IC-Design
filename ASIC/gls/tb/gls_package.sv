/* 
* gls_package included all components for gls_test
*/

package gls_package;
    `include "./test_classes/soc_packet.sv"
    `include "./test_classes/gls_debug_scoreboard.sv"
    `include "./test_classes/gls_driver.sv"
    `include "./test_classes/gls_monitor.sv"
    `include "./test_classes/gls_debug_generator.sv"
    `include "./test_classes/gls_environment.sv"
    `include "./test_classes/gls_test.sv"
endpackage