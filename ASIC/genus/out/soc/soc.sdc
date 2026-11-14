# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.13-s073_1 on Fri Nov 13 16:52:28 PST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design soc_synth_top

create_clock -name "clk" -period 12.5 -waveform {0.0 6.25} [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_dont_touch_network [get_clocks clk]
set_load -pin_load 0.05 [get_ports tx]
set_load -pin_load 0.05 [get_ports sclk]
set_load -pin_load 0.05 [get_ports mosi]
set_load -pin_load 0.05 [get_ports cs_n]
set_load -pin_load 0.05 [get_ports {gpio_inout[9]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[8]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[7]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[6]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[5]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[4]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[3]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[2]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[1]}]
set_load -pin_load 0.05 [get_ports {gpio_inout[0]}]
set_false_path -from [list \
  [get_ports rx]  \
  [get_ports rst_n]  \
  [get_ports {gpio_inout[0]}]  \
  [get_ports {gpio_inout[1]}]  \
  [get_ports {gpio_inout[2]}]  \
  [get_ports {gpio_inout[3]}]  \
  [get_ports {gpio_inout[4]}]  \
  [get_ports {gpio_inout[5]}]  \
  [get_ports {gpio_inout[6]}]  \
  [get_ports {gpio_inout[7]}]  \
  [get_ports {gpio_inout[8]}]  \
  [get_ports {gpio_inout[9]}] ]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports miso]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports miso]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports tx]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports sclk]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports mosi]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports cs_n]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports tx]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports sclk]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports mosi]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports cs_n]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[9]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[9]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[8]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[8]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 2.0 [get_ports {gpio_inout[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[9]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[9]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[8]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[8]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {gpio_inout[0]}]
set_max_fanout 20.000 [current_design]
set_max_transition 0.2 [current_design]
set_input_transition 0.03 [get_ports rst_n]
set_input_transition 0.03 [get_ports rx]
set_input_transition 0.03 [get_ports miso]
set_input_transition 0.03 [get_ports {gpio_inout[9]}]
set_input_transition 0.03 [get_ports {gpio_inout[8]}]
set_input_transition 0.03 [get_ports {gpio_inout[7]}]
set_input_transition 0.03 [get_ports {gpio_inout[6]}]
set_input_transition 0.03 [get_ports {gpio_inout[5]}]
set_input_transition 0.03 [get_ports {gpio_inout[4]}]
set_input_transition 0.03 [get_ports {gpio_inout[3]}]
set_input_transition 0.03 [get_ports {gpio_inout[2]}]
set_input_transition 0.03 [get_ports {gpio_inout[1]}]
set_input_transition 0.03 [get_ports {gpio_inout[0]}]
set_wire_load_mode "top"
set_clock_uncertainty -setup 0.3 [get_clocks clk]
set_clock_uncertainty -hold 0.3 [get_clocks clk]
