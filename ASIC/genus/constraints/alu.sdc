# Period 12.5 ns = 80 MHz
create_clock -name vclk -period 12.5
set_input_delay  -clock vclk 1.0 [all_inputs]
set_output_delay -clock vclk 1.0 [all_outputs]