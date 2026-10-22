# Settings for Genus Runs:
set REPO_ROOT $env(REPO_ROOT)
set GENUS_DIR $env(GENUS_DIR)
set DESIGN    $env(DESIGN)

# SKY130 PDK Settings:
set PDK_ROOT    /opt/open_pdks/sky130/sky130A
set STD_LIB_DIR $PDK_ROOT/libs.ref/sky130_fd_sc_hd/lib
set STD_LIB     $STD_LIB_DIR/sky130_fd_sc_hd__tt_025C_1v80.lib   ;

set EXTRA_LIBS {}

# Design-Specific Settings:
array set TOP_OF {
    alu  alu_synth_top
}
set TOP_MODULE $TOP_OF($DESIGN)
set FILELIST   $GENUS_DIR/filelists/$DESIGN.f
set SDC_FILE   $GENUS_DIR/constraints/$DESIGN.sdc

set INCLUDE_DIRS [list $REPO_ROOT/RTL/memory]

# Output Directories:
set OUT_DIR $GENUS_DIR/out/$DESIGN
set RPT_DIR $GENUS_DIR/reports/$DESIGN
