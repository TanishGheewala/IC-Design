add_search_path . /opt/cadence/installs/DDI231/GENUS231/tools.lnx86/lib/tech -library -both
read_library -liberty -both \
    /opt/open_pdks/sky130/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
    /tapeout/IC-Design/ASIC/macros/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib

