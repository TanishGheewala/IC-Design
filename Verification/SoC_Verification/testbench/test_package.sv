/* 
* test_package included all components for soc_test
*/

package test_package;
    `include "./test_classes/soc_packet.sv"
    `include "./test_classes/soc_debug_scoreboard.sv"
    `include "./test_classes/soc_driver.sv"
    `include "./test_classes/soc_monitor.sv"
    `include "./test_classes/soc_debug_generator.sv"
    `include "./test_classes/soc_environment.sv"
    `include "./test_classes/soc_test.sv"
endpackage