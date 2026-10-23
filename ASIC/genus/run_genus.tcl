# Launch with: ./run_genus.sh <design>

source $env(GENUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR

read_libs [concat $STD_LIB $EXTRA_LIBS]

set_db init_hdl_search_path $INCLUDE_DIRS
set files {}
set fp [open $FILELIST r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line]} continue
    lappend files [file join $REPO_ROOT $line]
}
close $fp
read_hdl -sv $files
elaborate $TOP_MODULE

read_sdc $SDC_FILE
syn_generic
syn_map
syn_opt

report_timing > $RPT_DIR/${DESIGN}_timing.rpt
report_area   > $RPT_DIR/${DESIGN}_area.rpt
report_power  > $RPT_DIR/${DESIGN}_power.rpt
write_hdl > $OUT_DIR/${DESIGN}_netlist.v
write_sdc > $OUT_DIR/${DESIGN}.sdc
exit