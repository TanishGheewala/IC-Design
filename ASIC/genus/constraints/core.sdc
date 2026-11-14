#SDC constraints for core

#sets max amount of gates something can drive without buffers
set_max_fanout 20 [current_design]
#sets a max transision time so that genus can choose sizes to keep that true
set_max_transition 0.20 [current_design]

#80MHz CLK 
create_clock -name clk -period 12.500 [get_ports clk]
#uncertainty is for the timing differences for things like longer wire distance 2% to 5% of clk
set_clock_uncertainty 0.3 [get_clocks clk]
# transiston is for ramp up time
set_clock_transition 0.1 [get_clocks clk]

#async pins - designates pins as async so they dont need to be matched with clk
set_false_path -from [get_ports rst_n]

#input delays - tells genus the possible timeframe for when data arrives - ie: time spent before reaching this block
set_input_delay -clock clk -max 2.0 [get_ports {core_halt}]
set_input_delay -clock clk -min 0.2 [get_ports {core_halt}]
set_input_delay -clock clk -max 2.0 [get_ports {debug_controller_instruction[*] debug_address[*] memory_read[*] rom_read[*]}]
set_input_delay -clock clk -min 0.2 [get_ports {debug_controller_instruction[*] debug_address[*] memory_read[*] rom_read[*]}]

#output delays - same as input delay but for outputs so saying there will need this much time later
set_output_delay -clock clk -max 2.0 [get_ports {memory_write_en}]
set_output_delay -clock clk -min 0.2 [get_ports {memory_write_en}]
set_output_delay -clock clk -max 2.0 [get_ports {debug_data_return[*] memory_write_mask[*] memory_address[*] memory_write[*] rom_address[*]}]
set_output_delay -clock clk -min 0.2 [get_ports {debug_data_return[*] memory_write_mask[*] memory_address[*] memory_write[*] rom_address[*]}]

#used to prevent genus from toucing clk
set_dont_touch_network [get_clocks clk]

#sets load to outputs to represent external load on pins from future logic, genus will pick stronger libs than if this is not set
set_input_transition 0.03 [get_ports {core_halt debug_controller_instruction[*] debug_address[*] memory_read[*] rom_read[*]}]
set_load 0.05 [all_outputs]
