# 80 MHz target (12.5 ns)

create_clock -name clk -period 12.5 [get_ports clk]
set_input_delay  -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]