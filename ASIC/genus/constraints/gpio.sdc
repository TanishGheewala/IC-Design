
# GPIO Constraints
# Target Frequency: 80 MHz, 12.5 ns period

create_clock -name CLK -period 12.500 -waveform {0 6.250} [get_ports clk]

# Margin for jitter/skew on setup checks: acts as if each cycle were 0.05 ns
# shorter.
set_clock_uncertainty -setup 0.05 [get_clocks CLK]

# Extra 0.03 ns margin required on hold checks.
set_clock_uncertainty -hold  0.03 [get_clocks CLK]

# Assume the clock edge takes 0.05 ns to switch (realistic slew for the ideal,
# pre-CTS clock).
set_clock_transition         0.05 [get_clocks CLK]

# gpio_in is asynchronous because it comes from the padsto the clock, so false path it.
set_false_path -from [get_ports gpio_in]

#gpio_out and gpio_oe are outputs to the pads 
set_output_delay -max 1.00 -clock CLK [get_ports gpio_out]
set_output_delay -min 0.05 -clock CLK [get_ports gpio_out]

set_output_delay -max 1.00 -clock CLK [get_ports gpio_oe]
set_output_delay -min 0.05 -clock CLK [get_ports gpio_oe]

# set input transition for inputs and set_load for outputs

