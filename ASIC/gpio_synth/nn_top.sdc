# =============================================================================
# File        : nn_top.sdc
# Design      : nn_top
# Target freq : 200 MHz, 5.000 ns period
# =============================================================================

# No gate output may drive more than 20 inputs; synthesis buffers or
# duplicates logic on nets with higher fanout.
set_max_fanout 20 [current_design]

# Every signal must switch (0->1 or 1->0) within 0.20 ns; the tool upsizes
# drivers or adds buffers to keep edges sharp.
set_max_transition 0.20 [current_design]

# -----------------------------------------------------------------------------
# Clock definition
# -----------------------------------------------------------------------------

# Define clock "CLK" on input port CLK: 5 ns period (200 MHz), rising edge at
# 0 ns, falling edge at 2.5 ns (50% duty cycle). All timing is relative to it.
create_clock -name CLK -period 5.000 -waveform {0 2.500} [get_ports CLK]

# Margin for jitter/skew on setup checks: acts as if each cycle were 0.05 ns
# shorter.
set_clock_uncertainty -setup 0.05 [get_clocks CLK]

# Extra 0.03 ns margin required on hold checks.
set_clock_uncertainty -hold  0.03 [get_clocks CLK]

# Assume the clock edge takes 0.05 ns to switch (realistic slew for the ideal,
# pre-CTS clock).
set_clock_transition         0.05 [get_clocks CLK]

# Do not buffer or resize the clock net during synthesis; the clock tree is
# built later during place & route (CTS).
set_dont_touch_network [get_clocks CLK]

# -----------------------------------------------------------------------------
# Input delays: when data arrives at each input, measured from the CLK edge,
# as if driven by an external flip-flop.
#   -max : worst-case (latest) arrival  -> used for SETUP checks
#   -min : best-case (earliest) arrival -> used for HOLD checks
# With -max 1.00, internal logic gets ~5 - 1 - 0.05 = 3.95 ns.
# -----------------------------------------------------------------------------

# Reset input (note: false-pathed below, so these two lines have no effect)
set_input_delay -max 1.00 -clock CLK [get_ports RST]
set_input_delay -min 0.05 -clock CLK [get_ports RST]

# Input-valid handshake signal
set_input_delay -max 1.00 -clock CLK [get_ports VALID_IN]
set_input_delay -min 0.05 -clock CLK [get_ports VALID_IN]

# Red channel input
set_input_delay -max 1.00 -clock CLK [get_ports R_IN]
set_input_delay -min 0.05 -clock CLK [get_ports R_IN]

# Green channel input
set_input_delay -max 1.00 -clock CLK [get_ports G_IN]
set_input_delay -min 0.05 -clock CLK [get_ports G_IN]

# Blue channel input
set_input_delay -max 1.00 -clock CLK [get_ports B_IN]
set_input_delay -min 0.05 -clock CLK [get_ports B_IN]

# -----------------------------------------------------------------------------
# Output delays: timing required by the external logic that receives outputs.
#   -max 1.00 : downstream needs 1 ns setup -> outputs must be stable by
#               ~5 - 1 = 4 ns into the cycle (SETUP check)
#   -min 0.05 : downstream hold requirement (HOLD check)
# -----------------------------------------------------------------------------

# Red channel output
set_output_delay -max 1.00 -clock CLK [get_ports R_OUT]
set_output_delay -min 0.05 -clock CLK [get_ports R_OUT]

# Green channel output
set_output_delay -max 1.00 -clock CLK [get_ports G_OUT]
set_output_delay -min 0.05 -clock CLK [get_ports G_OUT]

# Blue channel output
set_output_delay -max 1.00 -clock CLK [get_ports B_OUT]
set_output_delay -min 0.05 -clock CLK [get_ports B_OUT]

# Output-valid handshake signal
set_output_delay -max 1.00 -clock CLK [get_ports VALID_OUT]
set_output_delay -min 0.05 -clock CLK [get_ports VALID_OUT]

# -----------------------------------------------------------------------------
# Output load
# -----------------------------------------------------------------------------

# Every output drives a 0.005 capacitive load (5 fF if library units are pF);
# used to compute output delay and size output drivers.
set_load 0.005 [all_outputs]

# -----------------------------------------------------------------------------
# Reset
# -----------------------------------------------------------------------------

# Do not time any path starting at RST (asynchronous / quasi-static reset).
set_false_path -from [get_ports RST]

# -----------------------------------------------------------------------------
# Scan / test (DFT) signals
# Note: if nn_top has no scan ports yet, these lines only produce warnings.
# -----------------------------------------------------------------------------

# Hold scan_en at constant 0 for analysis -> time functional mode only.
set_case_analysis 0 [get_ports scan_en]

# Hold test_mode at constant 0 for analysis -> time functional mode only.
set_case_analysis 0 [get_ports test_mode]

# Don't time paths from the scan-enable port (scan runs at a slow test clock).
set_false_path -from [get_ports scan_en]

# Don't time paths from the test-mode port.
set_false_path -from [get_ports test_mode]

# Don't time paths from the scan-chain input.
set_false_path -from [get_ports scan_in]

# Don't time paths to the scan-chain output.
set_false_path -to   [get_ports scan_out]
