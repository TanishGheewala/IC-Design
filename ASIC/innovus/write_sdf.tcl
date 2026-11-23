###############################################################################
# write_sdf.tcl -- export SDF from the saved final database, no P&R re-run.
#
#   cd ASIC/innovus
#   DESIGN=soc INNOVUS_DIR=$PWD REPO_ROOT=$(cd ../.. && pwd) \
#       innovus -nowin -files write_sdf.tcl -log logs/write_sdf_soc.log
#
# Output: out/<design>/<design>.sdf   (consumed by ASIC/gls/run_gls.sh -m sdf)
###############################################################################
foreach {var dflt} [list INNOVUS_DIR [pwd] DESIGN soc] {
    if {![info exists ::env($var)]} { set ::env($var) $dflt }
}
if {![info exists ::env(REPO_ROOT)]} {
    set ::env(REPO_ROOT) [file normalize $::env(INNOVUS_DIR)/../..]
}

# Load config + procs only (INTERACTIVE stops run_innovus.tcl from running the flow)
set ::INTERACTIVE 1
source $::env(INNOVUS_DIR)/run_innovus.tcl

set db $DBS_DIR/${DESIGN}_final.enc.dat
if {![file exists $db]} {
    puts "ERROR: no saved database at $db -- run ./run_innovus.sh $DESIGN first"
    exit 1
}
restoreDesign $db $TOP_MODULE
write_gls_sdf
exit
