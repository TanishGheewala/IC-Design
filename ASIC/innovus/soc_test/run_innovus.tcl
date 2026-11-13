# =============================================================================
# Cadence Innovus P&R: Floorplan, SRAM Placement, Core Placement, Image Dump
# =============================================================================

# 1. Environment & Path Resolution
set REPO_ROOT [file normalize "../.."]
set DESIGN    "soc_synth_top"
set PDK_ROOT  "/opt/open_pdks/sky130/sky130A"

# Auto-detect Tech LEF filename
set TECH_LEF "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef"
if {![file exists $TECH_LEF]} {
    set TECH_LEF "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef"
}

# Physical Cell LEF and SRAM Macro LEF
set SC_LEF    "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef"
set SRAM_LEF  "$REPO_ROOT/ASIC/sky130_ram_macros/sky130_sram_2kbyte_1rw1r_32x512_8.lef"

# Netlist and Constraints (from Genus out/soc directory)
set NETLIST   "$REPO_ROOT/ASIC/genus/out/soc/soc_netlist.v"
set SDC_FILE  "$REPO_ROOT/ASIC/genus/out/soc/soc.sdc"

# Liberty Timing Files
set STD_LIB   "$PDK_ROOT/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set SRAM_LIB  "$REPO_ROOT/ASIC/sky130_ram_macros/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib"

# -----------------------------------------------------------------------------
# 2. Design Initialization
# -----------------------------------------------------------------------------
set init_verilog    $NETLIST
set init_top_cell   $DESIGN
set init_lef_file   [list $TECH_LEF $SC_LEF $SRAM_LEF]
set init_pwr_net    "VDD"
set init_gnd_net    "VSS"
set init_mmmc_file  "mmmc.tcl"

init_design

# -----------------------------------------------------------------------------
# 3. Create Floorplan (1.8mm x 1.8mm Square Die)
# -----------------------------------------------------------------------------
# Die width: 1800um, Die height: 1800um, Margin: 50um
floorPlan -d 1800 1800 50 50 50 50

# -----------------------------------------------------------------------------
# 4. Connect Global Power & Ground Nets
# -----------------------------------------------------------------------------
globalNetConnect VDD -type pgpin  -pin VPWR  -inst *
globalNetConnect VSS -type pgpin  -pin VGND  -inst *
globalNetConnect VDD -type tiehi  -inst *
globalNetConnect VSS -type tielo  -inst *

# Connect SRAM macro power pins
globalNetConnect VDD -type pgpin  -pin vccd1 -inst *
globalNetConnect VSS -type pgpin  -pin vssd1 -inst *

# -----------------------------------------------------------------------------
# 5. Place the 4 SRAM Blocks in the Corners
# -----------------------------------------------------------------------------
# Each SRAM is ~684um wide x ~417um tall.
# Bottom-Left: Bank 0 (Instruction)
placeInstance dut/instruction_rom/bank0 80 80 R0
# Top-Left: Bank 1 (Instruction)
placeInstance dut/instruction_rom/bank1 80 1250 R0
# Bottom-Right: Bank 2 (Instruction)
placeInstance dut/instruction_rom/bank2 1000 80 R0
# Top-Right: Bank 0 (Data Memory)
placeInstance dut/data_memory/bank0     1000 1250 R0

# Fix the SRAM locations so the standard cell placer does not move them
dbSet [dbGet -p top.insts.name *bank*].isFixed 1

# -----------------------------------------------------------------------------
# 6. Standard Cell Placement (CPU Core, RegFile, ALU, Peripherals)
# -----------------------------------------------------------------------------
setPlaceMode -prerouteResourceBudget false
place_design -noPrePlaceOpt

# -----------------------------------------------------------------------------
# 7. Zoom to Fit and Export Screenshot
# -----------------------------------------------------------------------------
fit

# Save screenshot to disk
dumpToGIF chip_layout.gif

puts "=========================================================="
puts "=== SUCCESS: Layout generated and saved to:           ==="
puts "=== ASIC/innovus/chip_layout.gif                       ==="
puts "=========================================================="