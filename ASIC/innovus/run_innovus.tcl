###############################################################################
# run_innovus.tcl  --  Place-and-route flow for the IC-Design chip (Innovus)
#
# Launch with:   ./run_innovus.sh <design>        (design = alu | core | system | soc)
#
# Consumes the Genus handoff (ASIC/genus/out/<design>/<design>_netlist.v + .sdc)
# and runs:  init -> floorplan -> (SRAM place) -> power -> place -> CTS ->
#            route -> optimize -> timing -> verify (DRC + connectivity) ->
#            save + GDS/netlist/SPEF out.
#
# The flow is written as one proc per step with a run-all driver at the bottom,
# so you can also source this file interactively and call steps one at a time
# while debugging (e.g.  step_init ; step_floorplan ; ...).
###############################################################################

source $env(INNOVUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR $DBS_DIR

# Use a few CPUs if the machine has them (harmless on a single-core box).
setMultiCpuUsage -localCpu 4

###############################################################################
# Sanity checks -- fail early with a clear message instead of deep in the tool
###############################################################################
proc check_file {label path} {
    if {![file exists $path]} {
        puts "ERROR: $label not found:\n    $path"
        puts "       (Run Genus first, or fix the path in config.tcl.)"
        exit 1
    }
}

proc step_check {} {
    global NETLIST SDC_FILE TECH_LEF STD_CELL_LEF STD_LIB
    global HAS_SRAM SRAM_LEF SRAM_LIB DESIGN TOP_MODULE
    puts "=== checking inputs for design '$DESIGN' (top: $TOP_MODULE) ==="
    check_file "Netlist"        $NETLIST
    check_file "SDC"            $SDC_FILE
    check_file "Tech LEF"       $TECH_LEF
    check_file "Std-cell LEF"   $STD_CELL_LEF
    check_file "Std-cell .lib"  $STD_LIB
    if {$HAS_SRAM} {
        check_file "SRAM LEF"   $SRAM_LEF
        check_file "SRAM .lib"  $SRAM_LIB
    }
}

###############################################################################
# 1. init -- build the MMMC view, read LEF + netlist, initialize the design
###############################################################################
proc step_init {} {
    global OUT_DIR SDC_FILE STD_LIB SRAM_LIB HAS_SRAM
    global TECH_LEF STD_CELL_LEF SRAM_LEF NETLIST TOP_MODULE
    global POWER_NET GROUND_NET

    # ---- Multi-Mode Multi-Corner setup (one typical corner) -----------------
    set libs [list $STD_LIB]
    if {$HAS_SRAM} { lappend libs $SRAM_LIB }

    set mmmc $OUT_DIR/mmmc.tcl
    set fp [open $mmmc w]
    puts $fp "create_library_set -name libs_tt -timing \[list $libs\]"
    puts $fp "create_rc_corner     -name rc_typ -T 25"
    puts $fp "create_delay_corner  -name corner_tt -library_set libs_tt -rc_corner rc_typ"
    puts $fp "create_constraint_mode -name func -sdc_files \[list $SDC_FILE\]"
    puts $fp "create_analysis_view -name view_tt -delay_corner corner_tt -constraint_mode func"
    puts $fp "set_analysis_view -setup {view_tt} -hold {view_tt}"
    close $fp

    # ---- Physical + logical inputs for init_design --------------------------
    set lefs [list $TECH_LEF $STD_CELL_LEF]
    if {$HAS_SRAM} { lappend lefs $SRAM_LEF }

    set init_mmmc_file $mmmc
    set init_lef_file  $lefs
    set init_verilog   $NETLIST
    set init_top_cell  $TOP_MODULE
    set init_pwr_net   $POWER_NET
    set init_gnd_net   $GROUND_NET

    init_design
    setDesignMode -process 130
}

###############################################################################
# 2. floorplan -- size the core from target utilization, then connect power
###############################################################################
proc step_floorplan {} {
    global TARGET_UTIL ASPECT CORE_MARGIN CORE_SITE
    global POWER_NET GROUND_NET HAS_SRAM

    floorPlan -site $CORE_SITE -r $ASPECT $TARGET_UTIL \
              $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN

    # Tie the logical power nets to the physical cell pins.
    # sky130_fd_sc_hd std cells: VPWR/VPB (power), VGND/VNB (ground).
    clearGlobalNets
    globalNetConnect $POWER_NET  -type pgpin -pin VPWR -all -verbose
    globalNetConnect $GROUND_NET -type pgpin -pin VGND -all -verbose
    globalNetConnect $POWER_NET  -type pgpin -pin VPB  -all -verbose
    globalNetConnect $GROUND_NET -type pgpin -pin VNB  -all -verbose
    globalNetConnect $POWER_NET  -type tiehi -all -verbose
    globalNetConnect $GROUND_NET -type tielo -all -verbose

    # SRAM macro power pins (vccd1/vssd1) tie to the same supplies.
    if {$HAS_SRAM} {
        globalNetConnect $POWER_NET  -type pgpin -pin vccd1 -all -verbose
        globalNetConnect $GROUND_NET -type pgpin -pin vssd1 -all -verbose
    }
}

###############################################################################
# 3. SRAM placement -- auto-discover macros and lay them out along the left
#    edge with a keep-out halo.  Tune coordinates here once you see the design;
#    for a first pass this spreads them evenly inside the core.
###############################################################################
proc step_place_sram {} {
    global HAS_SRAM SRAM_NAME
    if {!$HAS_SRAM} { puts "  (no SRAM in this design, skipping)"; return }

    set macros [get_cells -hierarchical -filter "ref_name==$SRAM_NAME"]
    if {[llength $macros] == 0} {
        puts "  WARNING: no instances of $SRAM_NAME found in the netlist."
        return
    }
    puts "  placing [llength $macros] SRAM macro(s): $macros"

    # Core box: {llx lly urx ury}
    set core [get_db current_design .core_bbox]
    set llx [lindex $core 0 0]; set lly [lindex $core 0 1]
    set urx [lindex $core 1 0]; set ury [lindex $core 1 1]

    # Stack macros up the left side, 20um in from the core edge.
    set x [expr {$llx + 20}]
    set y [expr {$lly + 20}]
    set pitch_y 0
    foreach m $macros {
        set inst [get_db $m .name]
        placeInstance $inst $x $y R0 -fixed
        # keep standard cells a few microns clear of the macro
        addHaloToBlock -allMacro 5 5 5 5
        # next macro higher up (bump 250um; adjust to the real macro height)
        set y [expr {$y + 250}]
        if {$y > [expr {$ury - 200}]} { set y [expr {$lly + 20}]; set x [expr {$x + 350}] }
    }
}

###############################################################################
# 4. power grid -- core rings + vertical/horizontal stripes, then sroute to
#    hook up the stripes, std-cell rails and macro pins.
###############################################################################
proc step_power {} {
    global POWER_NET GROUND_NET

    # Ring around the core on metal4/metal5.
    addRing -nets [list $POWER_NET $GROUND_NET] \
            -type core_rings -follow core \
            -layer {top met5 bottom met5 left met4 right met4} \
            -width 3 -spacing 2 -offset 2

    # Vertical power stripes on met4 across the core.
    addStripe -nets [list $POWER_NET $GROUND_NET] \
              -layer met4 -direction vertical \
              -width 1.5 -spacing 2 -set_to_set_distance 50 \
              -start_from left -switch_layer_over_obs false

    # Connect stripes + follow-pin rails + macro pins.
    setSrouteMode -viaConnectToShape { ring stripe }
    sroute -connect { blockPin padPin padRing corePin floatingStripe } \
           -layerChangeRange { met1 met5 } \
           -nets [list $POWER_NET $GROUND_NET]
}

###############################################################################
# 5. place -- standard-cell placement with optimization
###############################################################################
proc step_place {} {
    setPlaceMode -place_global_place_io_pins true
    place_opt_design
    checkPlace
}

###############################################################################
# 6. CTS -- only meaningful if the design has clocked logic.  The ALU is purely
#    combinational (virtual clock only), so this becomes a no-op there.
###############################################################################
proc step_cts {} {
    if {[llength [all_registers]] == 0} {
        puts "  no registers in this design -> skipping clock tree synthesis."
        return
    }
    create_clock_tree_spec
    ccopt_design
}

###############################################################################
# 7. route -- global + detailed route, then post-route optimization
###############################################################################
proc step_route {} {
    global MAX_ROUTE_LAYER
    setNanoRouteMode -routeTopRoutingLayer $MAX_ROUTE_LAYER
    setNanoRouteMode -routeWithTimingDriven true
    routeDesign
    optDesign -postRoute
}

###############################################################################
# 8. timing -- setup + hold summary reports
###############################################################################
proc step_timing {} {
    global RPT_DIR DESIGN
    timeDesign -postRoute                 -outDir $RPT_DIR/timing_setup
    timeDesign -postRoute -hold           -outDir $RPT_DIR/timing_hold
    report_timing -nworst 10 > $RPT_DIR/${DESIGN}_timing.rpt
}

###############################################################################
# 9. verify -- DRC (geometry) and connectivity (opens/shorts)
###############################################################################
proc step_verify {} {
    global RPT_DIR DESIGN
    verify_drc          -report $RPT_DIR/${DESIGN}_drc.rpt
    verifyConnectivity  -type all -report $RPT_DIR/${DESIGN}_conn.rpt
    checkDesign -all -outfile $RPT_DIR/${DESIGN}_checkdesign.rpt
}

###############################################################################
# 10. save -- design database, final netlist, SPEF, DEF and GDSII
###############################################################################
proc step_save {} {
    global DBS_DIR OUT_DIR DESIGN TOP_MODULE GDS_MAP STD_GDS SRAM_GDS HAS_SRAM

    saveDesign $DBS_DIR/${DESIGN}_final.enc
    saveNetlist $OUT_DIR/${DESIGN}_pnr_netlist.v
    rcOut -spef $OUT_DIR/${DESIGN}.spef
    defOut -floorplan -netlist -routing $OUT_DIR/${DESIGN}.def

    set merge [list $STD_GDS]
    if {$HAS_SRAM} { lappend merge $SRAM_GDS }
    streamOut $OUT_DIR/${DESIGN}.gds \
        -mapFile $GDS_MAP \
        -merge $merge \
        -units 1000 -mode ALL
    puts "=== GDSII written: $OUT_DIR/${DESIGN}.gds ==="
}

###############################################################################
# Run-all driver
###############################################################################
proc run_all {} {
    step_check
    step_init
    step_floorplan
    step_place_sram
    step_power
    step_place
    step_cts
    step_route
    step_timing
    step_verify
    step_save
    puts "\n=== P&R flow complete for design '$::DESIGN' ===\n"
}

# Run everything unless the user sourced this file to drive steps by hand.
if {![info exists ::INTERACTIVE]} {
    run_all
    exit
}
