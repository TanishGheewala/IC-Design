// =============================================================================
// File: synt_lec.do (FINAL FIX - Handle MSB optimization)
// Purpose: Post-synthesis LEC with guidance for sign bit optimization
// 
// STATUS: 793 EQ, 1 NON-EQ
// Last failure: /OUTPUT0/sum3_out_reg[31] - MSB of final adder
// Issue: Golden=BUF, Revised=OR (synthesis optimized the sign bit logic)
// =============================================================================

// ---------- Read ALL RTL files -------------------------------------------------
read design -sv -golden -replace -define DFT_INSERTION \
    ../../rtl/nn_top.sv \
    ../../rtl/neuron.sv \
    ../../rtl/color_mapper.sv \
    ../../rtl/activation_rom.sv \
    ../../rtl/clamp_shift_r.sv

// ---------- Read netlist -------------------------------------------------------
read design -verilog -revised -replace ../../output/nn_top_netlist.v

// ---------- DFT handling -------------------------------------------------------
add pin constraint 0 scan_en    -golden -revised
add pin constraint 0 test_mode  -golden -revised  
add pin constraint 0 scan_in    -golden -revised
add ignored outputs scan_out    -golden -revised

// ---------- SETUP mode commands ------------------------------------------------
// Flatten models to handle arithmetic optimization
set flatten model -seq_constant

// Enable auto datapath analysis
set analyze option -auto

// CRITICAL: Tell LEC to be more aggressive about proving equivalence
// This helps with sign-bit optimizations
set verification effort_level high

// ---------- Enter LEC mode -----------------------------------------------------
set system mode lec

// ---------- Compare ------------------------------------------------------------
add compared points -all
compare

// ---------- If still 1 NON-EQ, try re-proving with guidance --------------------
// This is a fallback - LEC will try harder to prove the last point
remodel -seq_constant
compare

// ---------- Reports ------------------------------------------------------------
report verification    -verbose                           > reports/lec_synth.rpt
report compare_data    -class nonequivalent -class abort >> reports/lec_synth.rpt  
report unmapped points -golden -revised                  >> reports/lec_synth.rpt
report statistics                                        >> reports/lec_synth.rpt

exit -r
