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

# Checks RTL for undriven nets or any issues before synthesis
check_design -all > $RPT_DIR/${DESIGN}_check_design.rpt

read_sdc $SDC_FILE

# Lists paths and ports that the SDC files doesn't constrain
check_timing_intent > $RPT_DIR/${DESIGN}_timing_intent.rpt

syn_generic
syn_map
syn_opt

report_timing > $RPT_DIR/${DESIGN}_timing.rpt
report_area   > $RPT_DIR/${DESIGN}_area.rpt
report_power  > $RPT_DIR/${DESIGN}_power.rpt
report_qor    > $RPT_DIR/${DESIGN}_qor.rpt
write_hdl > $OUT_DIR/${DESIGN}_netlist.v
write_sdc > $OUT_DIR/${DESIGN}.sdc

# LEC file for LEQ Check
write_do_lec -revised_design $OUT_DIR/${DESIGN}_netlist.v \
             -logfile $RPT_DIR/${DESIGN}_lec.log \
             > $RPT_DIR/${DESIGN}_lec.do
exit