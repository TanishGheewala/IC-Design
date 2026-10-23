# run_genus.tcl -- synthesis flow. Run via:  ./run_genus.sh <design>
source $env(GENUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR

# Read a file list: one path per line, relative to the repo root; # = comment
proc read_filelist {f root} {
    set fp [open $f r]
    set files {}
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} continue
        lappend files [file join $root $line]
    }
    close $fp
    return $files
}

puts "=== Genus: design=$DESIGN top=$TOP_MODULE ==="

# 1. Libraries
set_db init_lib_search_path $STD_LIB_DIR
set_db init_hdl_search_path $INCLUDE_DIRS
read_libs [concat $STD_LIB $EXTRA_LIBS]

# 2. RTL
read_hdl -sv [read_filelist $FILELIST $REPO_ROOT]
elaborate $TOP_MODULE
check_design -unresolved

# 3. Constraints
read_sdc $SDC_FILE

# 4. Synthesis
set_db syn_generic_effort medium
set_db syn_map_effort     medium
set_db syn_opt_effort     medium
syn_generic
syn_map
syn_opt

# 5. Reports
report_qor    > $RPT_DIR/${DESIGN}_qor.rpt
report_timing > $RPT_DIR/${DESIGN}_timing.rpt
report_area   > $RPT_DIR/${DESIGN}_area.rpt
report_power  > $RPT_DIR/${DESIGN}_power.rpt
report_gates  > $RPT_DIR/${DESIGN}_gates.rpt

# 6. Handoff files for Innovus (Person 2)
write_hdl > $OUT_DIR/${DESIGN}_netlist.v
write_sdc > $OUT_DIR/${DESIGN}.sdc

puts "=== Genus done: outputs in $OUT_DIR, reports in $RPT_DIR ==="
exit
