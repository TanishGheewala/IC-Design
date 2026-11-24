## White LEDs (GPIO[6:0] -> led_0[6:0], 1.2V Bank)
set_property PACKAGE_PIN AF5 [get_ports {led_0[0]}]
set_property PACKAGE_PIN AE7 [get_ports {led_0[1]}]
set_property PACKAGE_PIN AH2 [get_ports {led_0[2]}]
set_property PACKAGE_PIN AE5 [get_ports {led_0[3]}]
set_property PACKAGE_PIN AH1 [get_ports {led_0[4]}]
set_property PACKAGE_PIN AE4 [get_ports {led_0[5]}]
set_property PACKAGE_PIN AG1 [get_ports {led_0[6]}]
set_property IOSTANDARD LVCMOS12 [get_ports {led_0[*]}]

## PMOD JA Pins 1-3 (GPIO[9:7] -> pmod_0[2:0], 3.3V Bank)
set_property PACKAGE_PIN J12 [get_ports {pmod_0[0]}]
set_property PACKAGE_PIN H12 [get_ports {pmod_0[1]}]
set_property PACKAGE_PIN H11 [get_ports {pmod_0[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {pmod_0[*]}]

## Bitstream Configuration
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]