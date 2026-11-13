# EQY-only settings.
# Designs, filelists, libraries and output folders come from ../config.tcl.

# Macros defined when reading the golden RTL. SYNTHESIS hides simulation-only
# code wrapped in `ifndef SYNTHESIS ($strobe, $display, $monitor, ...).
set EQY_DEFINES {SYNTHESIS}

# Proof depth (clock cycles) for each partition. Raise it for a design whose
# partitions come back unproven, e.g. add "core 20" inside the braces below.
set EQY_DEPTH_DEFAULT 10
array set EQY_DEPTH {
}

# SBY solver engine.
set EQY_ENGINE "smtbmc yices"
