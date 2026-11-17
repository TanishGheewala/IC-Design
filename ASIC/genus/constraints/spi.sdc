
#SPI Bootloader SDC constraints

create_clock -name CLK -period 12.500 -waveform {0 6.250} [get_ports clk]

set_clock_uncertainty -setup 0.05 [get_clocks CLK]
set_clock_uncertainty -hold  0.03 [get_clocks CLK]

# Assume the clock edge takes 0.05 ns to switch (realistic slew for the ideal,
# pre-CTS clock).
set_clock_transition         0.05 [get_clocks CLK]

set_input_delay -max 1.00 -clock CLK [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -min 0.05 -clock CLK [remove_from_collection [all_inputs] [get_ports clk]]

set_output_delay -max 1.00 -clock CLK [all_outputs]
set_output_delay -min 0.05 -clock CLK [all_outputs]

set_input_transition 0.03 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.05 [all_outputs]