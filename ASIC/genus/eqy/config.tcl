# EQY-only settings.
# Designs, filelists, libraries and output folders come from ../config.tcl.

# Macros defined when reading the golden RTL. SYNTHESIS hides simulation-only
# code wrapped in `ifndef SYNTHESIS ($strobe, $display, $monitor, ...).
set EQY_DEFINES {SYNTHESIS}

# 1 = read cleaned copies of the RTL with simulation-only print calls
# ($display, $strobe, $monitor, $write and their $f... variants) replaced by
# ';', because yosys-slang rejects them. 0 = read the RTL files as they are.
set EQY_STRIP_SIM_TASKS 1

# Proof depth (clock cycles) for each partition. Raise it for a design whose
# partitions come back unproven, e.g. add "core 20" inside the braces below.
set EQY_DEPTH_DEFAULT 10
array set EQY_DEPTH {
}

# 1 = keep EQY's long output out of the terminal (it goes to
# eqy/work/<design>.out and reports/<design>/<design>_eqy.log) and show only
# progress lines and the summary table. 0 = stream everything as before.
set EQY_QUIET 1

# SBY solver engine.
set EQY_ENGINE "smtbmc yices"
