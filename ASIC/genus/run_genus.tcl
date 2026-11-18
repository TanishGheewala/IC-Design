# Launch with: ./run_genus.sh <design>

source $env(GENUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR

# Cap to 2 threads for the dual-core workstation
# set_db max_cpus_per_server 2

read_libs [concat $STD_LIB $EXTRA_LIBS]

# Must be set before elaborate so unused/feedback logic isn't pruned at elaboration
# set_db hdl_preserve_unused_registers true
# set_db hdl_preserve_unused_flop true
# set_db hdl_cdfg_early_redundancy_removal false
# set_db hdl_ff_keep_feedback true

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

# Keep hierarchy, FF boundaries, and constants intact for Yosys EQY (and Innovus macro paths)
set_db auto_ungroup none
if {[llength [get_db modules *]] > 0} {
    set_db [get_db modules *] .boundary_opto false
}

# set_db boundary_optimize_constant_hpins false
# set_db boundary_optimize_equal_opposite_hpins false
# set_db boundary_optimize_feedthrough_hpins false
# set_db dp_ungroup_during_syn_map false
# set_db merge_combinational_hier_instances false

# set_db delete_unloaded_seqs false
# set_db optimize_constant_0_flops false
# set_db optimize_constant_1_flops false
# set_db optimize_constant_feedback_seqs false
# set_db optimize_constant_latches false
# set_db optimize_constant_across_preserved false
# set_db optimize_merge_flops false
# set_db optimize_merge_latches false

# set_db opt_preserve_all_sequential true
# set_db opt_preserve_hpin_function true
# set_db opt_constant_nets false

# set_db iopt_sequential_duplication false
# set_db iopt_sequential_resynthesis false
# set_db use_multibit_cells false
# set_db lp_insert_clock_gating false

# Optional if FSM/control still diverges (check `help control_logic_optimization` first):
# set_db control_logic_optimization none
set_db use_scan_seqs_for_non_dft false

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
