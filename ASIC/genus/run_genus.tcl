# Launch with: ./run_genus.sh <design>

source $env(GENUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR

# Cap to 2 threads for the dual-core workstation
set_db max_cpus_per_server 2

read_libs [concat $STD_LIB $EXTRA_LIBS]

# Must be set before elaborate so unused registers aren't dropped at elaboration
set_db hdl_preserve_unused_registers true

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

# Keep hierarchy & FF boundaries intact for Yosys EQY (and Innovus macro paths)
set_db auto_ungroup none
set_db [get_db modules *] .boundary_opto false

set_db delete_unloaded_seqs false
set_db optimize_constant_0_flops false
set_db optimize_constant_1_flops false
set_db optimize_constant_feedback_seq false
set_db optimize_constant_latches false
set_db optimize_merge_flops false
set_db optimize_merge_latches false

set_db iopt_sequential_duplication false
set_db iopt_sequential_resynthesis false
set_db use_multibit_cells false
set_db lp_insert_clock_gating false

# Design- and module-level attributes (must come AFTER elaborate)
set_db [get_db designs *] .optimize_constant_0_seq false
set_db [get_db designs *] .optimize_constant_1_seq false
set_db [get_db designs *] .optimize_merge_seq false

if {[llength [get_db modules *]] > 0} {
    set_db [get_db modules *] .boundary_opto false
    set_db [get_db modules *] .optimize_constant_0_seq false
    set_db [get_db modules *] .optimize_constant_1_seq false
    set_db [get_db modules *] .optimize_merge_seq false
}

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