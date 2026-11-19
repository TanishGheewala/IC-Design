create_library_set -name libs_tt -timing [list /opt/open_pdks/sky130/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib /tapeout/IC-Design/ASIC/macros/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib]
create_rc_corner     -name rc_typ -T 25 
create_delay_corner  -name corner_tt -library_set libs_tt -rc_corner rc_typ
create_constraint_mode -name func -sdc_files [list /tapeout/IC-Design/ASIC/genus/out/soc/soc.sdc]
create_analysis_view -name view_tt -delay_corner corner_tt -constraint_mode func
set_analysis_view -setup {view_tt} -hold {view_tt}
