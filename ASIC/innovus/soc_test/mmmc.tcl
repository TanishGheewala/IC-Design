# =============================================================================
# Innovus MMMC Setup (Multi-Mode Multi-Corner)
# =============================================================================

# 1. Define Timing Libraries
create_library_set -name lib_typical \
    -timing [list $STD_LIB $SRAM_LIB]

# 2. Define Operating RC Corner (Typical 25C)
create_rc_corner -name rc_typical -T 25

# 3. Create Delay Corner
create_delay_corner -name delay_typical \
    -library_set lib_typical \
    -rc_corner rc_typical

# 4. Load SDC Constraints from Genus
create_constraint_mode -name func_mode \
    -sdc_files [list $SDC_FILE]

# 5. Create Analysis View & Activate for Setup and Hold
create_analysis_view -name view_typical \
    -delay_corner delay_typical \
    -constraint_mode func_mode

set_analysis_view -setup [list view_typical] -hold [list view_typical]