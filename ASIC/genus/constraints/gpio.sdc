
# GPIO Constraints
# Target Frequency: 80 MHz, 12.5 ns period

#max fanout and transition from library

create_clock -name CLK -period 12.500 -waveform {0 6.250} [get_ports clk]


set_clock_uncertainty -setup 0.05 [get_clocks CLK]
set_clock_uncertainty -hold  0.03 [get_clocks CLK]

# Assume the clock edge takes 0.05 ns to switch (realistic slew for the ideal,
# pre-CTS clock).
set_clock_transition         0.05 [get_clocks CLK]

# gpio_in is asynchronous because it comes from the padsto the clock, so false path it.
set_false_path -from [get_ports gpio_in]

#io input delays
set_input_delay -max 1.00 -clock CLK [get_ports wdata]
set_input_delay -min 0.05 -clock CLK [get_ports wdata]

set_input_delay -max 1.00 -clock CLK [get_ports addr]
set_input_delay -min 0.05 -clock CLK [get_ports addr]

set_input_delay -max 1.00 -clock CLK [get_ports rst_n]
set_input_delay -min 0.05 -clock CLK [get_ports rst_n]

set_input_delay -max 1.00 -clock CLK [get_ports {we sel}]
set_input_delay -min 0.05 -clock CLK [get_ports {we sel}]

#gpio_out and gpio_oe are outputs to the pads 
set_output_delay -max 1.00 -clock CLK [get_ports gpio_out]
set_output_delay -min 0.05 -clock CLK [get_ports gpio_out]

set_output_delay -max 1.00 -clock CLK [get_ports gpio_oe]
set_output_delay -min 0.05 -clock CLK [get_ports gpio_oe]

#io output delays
set_output_delay -max 1.00 -clock CLK [get_ports rdata]
set_output_delay -min 0.05 -clock CLK [get_ports rdata]

# set input transition for inputs and set_load for outputs
set_input_transition 0.03 [get_ports {addr wdata we sel rst_n gpio_in}]
set_load 0.005 [get_ports {rdata}]
set_load 0.05 [get_ports {gpio_out gpio_oe}]