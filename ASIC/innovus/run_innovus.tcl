###############################################################################
# run_innovus.tcl  --  Place-and-route flow for the IC-Design chip (Innovus)
#
# Launch with:   ./run_innovus.sh <design>        (design = alu | core | system | soc)
#
# Consumes the Genus handoff (ASIC/genus/out/<design>/<design>_netlist.v + .sdc)
# and runs:  init -> floorplan -> (SRAM place) -> well taps/end caps -> power ->
#            place (+ tie cells) -> CTS (+ hold fix) -> route (+ setup/hold
#            fix, fillers) -> timing -> verify (DRC + connectivity) ->
#            save + GDS/netlist/SPEF out.
#
# The flow is written as one proc per step with a run-all driver at the bottom,
# so you can also source this file interactively and call steps one at a time
# while debugging (e.g.  step_init ; step_floorplan ; ...).
###############################################################################

source $env(INNOVUS_DIR)/config.tcl
file mkdir $OUT_DIR $RPT_DIR $DBS_DIR

# Cap to 4 threads for the dual-core workstation (same as Genus).
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
    global NETLIST SDC_FILE TECH_LEF STD_CELL_LEF STD_LIB STD_GDS GDS_MAP
    global HAS_SRAM SRAM_LEF SRAM_LIB SRAM_GDS DESIGN TOP_MODULE QRC_TECH
    puts "=== checking inputs for design '$DESIGN' (top: $TOP_MODULE) ==="
    check_file "Netlist"        $NETLIST
    check_file "SDC"            $SDC_FILE
    check_file "Tech LEF"       $TECH_LEF
    check_file "Std-cell LEF"   $STD_CELL_LEF
    check_file "Std-cell .lib"  $STD_LIB
    # GDS inputs are only used at the very end (streamOut); check them now so a
    # missing file doesn't fail the run after hours of P&R.
    check_file "Std-cell GDS"   $STD_GDS
    check_file "GDS layer map"  $GDS_MAP
    if {$HAS_SRAM} {
        check_file "SRAM LEF"   $SRAM_LEF
        check_file "SRAM .lib"  $SRAM_LIB
        check_file "SRAM GDS"   $SRAM_GDS
    }
    if {$QRC_TECH ne ""} {
        check_file "RC tech file" $QRC_TECH
    } else {
        puts "  NOTE: no QRC_TECH set -> RC is estimated from the LEF (rough post-route timing)."
    }
}

# Tie logical power nets to the physical P/G pins. Called again after cells
# are added (tie cells, fillers) so every new instance gets connected too.
proc connect_global_nets {} {
    global POWER_NET GROUND_NET HAS_SRAM
    # sky130_fd_sc_hd std cells: VPWR/VPB (power), VGND/VNB (ground).
    # Constants (1'b0/1'b1) are NOT tied straight to the rails here; addTieHiLo
    # in step_place drives them from tie cells instead.
    clearGlobalNets
    globalNetConnect $POWER_NET  -type pgpin -pin VPWR -all
    globalNetConnect $GROUND_NET -type pgpin -pin VGND -all
    globalNetConnect $POWER_NET  -type pgpin -pin VPB  -all
    globalNetConnect $GROUND_NET -type pgpin -pin VNB  -all

    # SRAM macro power pins (vccd1/vssd1) tie to the same supplies.
    if {$HAS_SRAM} {
        globalNetConnect $POWER_NET  -type pgpin -pin vccd1 -all
        globalNetConnect $GROUND_NET -type pgpin -pin vssd1 -all
    }
}

###############################################################################
# 1. init -- build the MMMC view, read LEF + netlist, initialize the design
###############################################################################
proc step_init {} {
    global OUT_DIR SDC_FILE STD_LIB SRAM_LIB HAS_SRAM QRC_TECH
    global TECH_LEF STD_CELL_LEF SRAM_LEF NETLIST TOP_MODULE
    global POWER_NET GROUND_NET
    global init_mmmc_file init_lef_file init_verilog init_top_cell init_pwr_net init_gnd_net

    # ---- Multi-Mode Multi-Corner setup (one typical corner) -----------------
    set libs [list $STD_LIB]
    if {$HAS_SRAM} { lappend libs $SRAM_LIB }

    set mmmc $OUT_DIR/mmmc.tcl
    set fp [open $mmmc w]
    puts $fp "create_library_set -name libs_tt -timing \[list $libs\]"
    # RC tech: a QRC techfile (-qx_tech_file) or a cap table (-cap_table).
    set rc_opt ""
    if {$QRC_TECH ne ""} {
        if {[string match -nocase "*captable*" $QRC_TECH] || [string match -nocase "*.capTbl" $QRC_TECH]} {
            set rc_opt "-cap_table $QRC_TECH"
        } else {
            set rc_opt "-qx_tech_file $QRC_TECH"
        }
    }
    puts $fp "create_rc_corner     -name rc_typ -T 25 $rc_opt"
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

    # On-chip-variation timing with clock pessimism removal (CPPR). Post-route
    # optimization turns on SI (crosstalk) aware delay calculation, and the
    # delay engine (AAE) only allows SI optimization in OCV mode. Set here so
    # the whole flow is timed the same way, not just the post-route steps.
    setAnalysisMode -analysisType onChipVariation -cppr both
}

###############################################################################
# 2. floorplan -- size the core from target utilization, then connect power
###############################################################################
proc step_floorplan {} {
    global TARGET_UTIL ASPECT CORE_MARGIN CORE_SITE

    floorPlan -site $CORE_SITE -r $ASPECT $TARGET_UTIL \
              $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN

    connect_global_nets
}

###############################################################################
# 3. SRAM placement -- auto-discover macros and place them in a grid from the
#    lower-left corner of the core: left to right, then the next row up.
#    Spacing comes from the macro's real size in the LEF (683.1 x 416.54 um for
#    sky130_sram_2kbyte_1rw1r_32x512_8), plus a routing channel between them.
#    Replace with explicit placeInstance calls once you settle on a floorplan.
###############################################################################
proc step_place_sram {} {
    global HAS_SRAM SRAM_NAME
    if {!$HAS_SRAM} { puts "  (no SRAM in this design, skipping)"; return }

    # Edge gap from the core boundary and channel between macros (um).
    set edge    20
    set channel 30
    set halo    5

    # All leaf instances of the SRAM cell (hierarchical names included).
    set insts [dbGet -p2 top.insts.cell.name $SRAM_NAME]
    if {$insts eq "0x0" || [llength $insts] == 0} {
        puts "ERROR: no instances of $SRAM_NAME found in the netlist."
        exit 1
    }
    set names [dbGet $insts.name]
    puts "  placing [llength $names] SRAM macro(s): $names"

    # Macro size from the LEF: {{w h}}
    set size [dbGet [dbGet -p head.libCells.name $SRAM_NAME].size]
    set mw [lindex $size 0 0]
    set mh [lindex $size 0 1]

    # Core box: {{llx lly urx ury}}
    set core [dbGet top.fPlan.coreBox]
    set llx [lindex $core 0 0]; set lly [lindex $core 0 1]
    set urx [lindex $core 0 2]; set ury [lindex $core 0 3]
    puts "  core box: ($llx, $lly) - ($urx, $ury); macro: $mw x $mh um"

    set x [expr {$llx + $edge}]
    set y [expr {$lly + $edge}]
    foreach inst $names {
        # Start a new row if this macro would cross the right edge.
        if {$x + $mw > $urx - $edge} {
            set x [expr {$llx + $edge}]
            set y [expr {$y + $mh + $channel}]
        }
        if {$y + $mh > $ury - $edge} {
            puts "ERROR: SRAM macros don't fit in the core ($urx x $ury um)."
            puts "       Lower TARGET_UTIL or change ASPECT in config.tcl."
            exit 1
        }
        placeInstance $inst $x $y R0 -fixed
        set x [expr {$x + $mw + $channel}]
    }

    # Keep standard cells a few microns clear of every macro (applies to all).
    addHaloToBlock $halo $halo $halo $halo -allMacro
}

###############################################################################
# 3b. well taps + end caps -- sky130_fd_sc_hd cells have no built-in well
#     taps, so taps go in every row at TAP_INTERVAL; end caps close each row.
#     Done after macro placement so they avoid the macros and halos.
###############################################################################
proc step_physical_cells {} {
    global TAP_CELL TAP_INTERVAL ENDCAP_CELL
    addEndCap -preCap $ENDCAP_CELL -postCap $ENDCAP_CELL -prefix ENDCAP
    addWellTap -cell $TAP_CELL -cellInterval $TAP_INTERVAL -prefix WELLTAP
    connect_global_nets
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

    # Vertical power stripes on met4 across the core. The SRAM macros block
    # met4, so stripes are cut at the macros (not switched to another layer).
    addStripe -nets [list $POWER_NET $GROUND_NET] \
              -layer met4 -direction vertical \
              -width 1.5 -spacing 2 -set_to_set_distance 50 \
              -start_from left -switch_layer_over_obs false

    # Horizontal power stripes on met5 (met5 is free over the SRAMs, so these
    # also run across the macros and feed their met4 power pins).
    addStripe -nets [list $POWER_NET $GROUND_NET] \
              -layer met5 -direction horizontal \
              -width 3 -spacing 2 -set_to_set_distance 100 \
              -start_from bottom -switch_layer_over_obs false

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
    global TIE_CELL
    setPlaceMode -place_global_place_io_pins true
    # Constant 1'b0/1'b1 nets get driven by tie cells, not wired to the rails.
    setTieHiLoMode -cell $TIE_CELL -maxFanout 10
    place_opt_design
    addTieHiLo -cell $TIE_CELL -prefix TIE
    connect_global_nets
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
    global CTS_BUFFER_CELLS CTS_INVERTER_CELLS

    # Build the clock tree from the sky130 clock buffers/inverters only.
    set_ccopt_property buffer_cells   $CTS_BUFFER_CELLS
    set_ccopt_property inverter_cells $CTS_INVERTER_CELLS

    # Clock tree spec from the SDC clocks. The legacy UI (what this script
    # uses) calls it create_ccopt_clock_tree_spec; Stylus calls it
    # create_clock_tree_spec. Use whichever this Innovus has.
    if {[llength [info commands create_ccopt_clock_tree_spec]] > 0} {
        create_ccopt_clock_tree_spec
    } else {
        create_clock_tree_spec
    }
    # Newer releases: place_opt_design leaves the DB in the "PODv2" flow, which
    # ccopt_design rejects. clock_opt_design is its CTS step and includes the
    # post-CTS setup fix. Older releases only have ccopt_design + optDesign.
    if {[llength [info commands clock_opt_design]] > 0} {
        clock_opt_design
    } else {
        ccopt_design
        optDesign -postCTS
    }
    # The real clock tree changes timing: fix hold after the setup fix.
    optDesign -postCTS -hold
}

###############################################################################
# 7. route -- global + detailed route, then post-route optimization
###############################################################################
proc step_route {} {
    global MAX_ROUTE_LAYER ANTENNA_CELL FILLER_CELLS

    # Top routing layer: newer releases use setDesignMode; older ones only
    # have the (now obsolete) NanoRoute option.
    if {[catch {setDesignMode -topRoutingLayer $MAX_ROUTE_LAYER}]} {
        setNanoRouteMode -routeTopRoutingLayer $MAX_ROUTE_LAYER
    }
    setNanoRouteMode -routeWithTimingDriven true

    # sky130 antenna rules: fix by layer hopping, and insert diodes where needed.
    setNanoRouteMode -drouteFixAntenna true
    setNanoRouteMode -routeInsertAntennaDiode true
    setNanoRouteMode -routeAntennaCellName $ANTENNA_CELL

    routeDesign
    optDesign -postRoute
    optDesign -postRoute -hold

    # Fill the gaps left in the rows (keeps n-well and power rails continuous).
    addFiller -cell $FILLER_CELLS -prefix FILLER
    connect_global_nets
}

###############################################################################
# 8. timing -- setup + hold summary reports
###############################################################################
proc step_timing {} {
    global RPT_DIR DESIGN
    timeDesign -postRoute                 -outDir $RPT_DIR/timing_setup
    timeDesign -postRoute -hold           -outDir $RPT_DIR/timing_hold
    # -max_paths = total paths reported (-nworst is paths per endpoint)
    report_timing -max_paths 10 > $RPT_DIR/${DESIGN}_timing.rpt
}

###############################################################################
# 9. verify -- DRC (geometry) and connectivity (opens/shorts)
###############################################################################
proc step_verify {} {
    global RPT_DIR DESIGN
    # Default limit stops at 1000 violations, which hides the real count.
    verify_drc          -limit 100000 -report $RPT_DIR/${DESIGN}_drc.rpt
    verifyConnectivity  -type all -report $RPT_DIR/${DESIGN}_conn.rpt
    verifyProcessAntenna -reportfile $RPT_DIR/${DESIGN}_antenna.rpt

    # Some releases only take -outdir for checkDesign.
    if {[catch {checkDesign -all -outfile $RPT_DIR/${DESIGN}_checkdesign.rpt}]} {
        checkDesign -all -outdir $RPT_DIR/checkdesign
    }
}

###############################################################################
# 10. save -- design database, final netlist, SPEF, DEF and GDSII
###############################################################################
proc step_save {} {
    global DBS_DIR OUT_DIR DESIGN GDS_MAP STD_GDS SRAM_GDS HAS_SRAM
    global TAP_CELL ENDCAP_CELL FILLER_CELLS

    saveDesign $DBS_DIR/${DESIGN}_final.enc

    # Logical netlist (timing / LEC) and an LVS netlist with power pins and
    # the physical-only cells (taps, end caps, fillers) included.
    saveNetlist $OUT_DIR/${DESIGN}_pnr_netlist.v
    set phys_cells [lsort -unique [concat $TAP_CELL $ENDCAP_CELL $FILLER_CELLS]]
    saveNetlist $OUT_DIR/${DESIGN}_pnr_lvs.v \
        -includePowerGround -includePhysicalCell $phys_cells

    # Re-extract so the SPEF includes the hold buffers and fillers added
    # after the last extraction.
    extractRC
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
    step_physical_cells
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
# A Tcl error anywhere stops the run with a non-zero exit code instead of
# leaving Innovus sitting at its prompt.
if {![info exists ::INTERACTIVE]} {
    if {[catch {run_all} err]} {
        puts "ERROR: P&R flow stopped: $err"
        puts $::errorInfo
        exit 1
    }
    exit
}
