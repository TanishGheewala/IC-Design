#!/usr/bin/env bash
###############################################################################
# run_gls.sh -- post-Innovus gate-level simulation of soc_synth_top (Xcelium)
#
# Usage:  ./run_gls.sh [options]
#   -m func|sdf    func = zero/unit-delay functional GLS (default)
#                  sdf  = timing GLS: cell timing views + Innovus SDF back-annotation
#   -t max|min     sdf mode only: which SDF value to use (default max = setup-critical;
#                  min = hold-critical). Innovus writes (min::max) with no typical value.
#   -n pnr|genus  netlist to simulate (default pnr = innovus/out/soc/soc_pnr_netlist.v)
#   -x <file.hex>  use this program hex instead of building program/gls_test.s
#   -w             dump waves (SHM database, open later with: simvision sim/<run>/waves.shm)
#   -g             open the SimVision GUI (implies full debug access)
#   -c             clean the run directory first
#   -h             help
#
# Examples:
#   ./run_gls.sh                 # functional GLS on the post-route netlist
#   ./run_gls.sh -m sdf          # timing GLS (needs innovus/out/soc/soc.sdf)
#   ./run_gls.sh -m sdf -w       # same, with waveforms
#   ./run_gls.sh -m sdf -t min   # timing GLS with min delays (hold check)
#   ./run_gls.sh -n genus        # sanity re-run on the post-synthesis netlist
#
# Output lands in ASIC/gls/sim/<mode>_<netlist>/ (xrun.log, sdf_annotate.log, waves.shm)
#
# NOTE: the test sends a 160-byte image over 9600-baud UART twice, so it covers
# ~820 ms of chip time. Expect a long run (the xsim version took ~7.7 h); run it
# under nohup/screen/tmux on the lab machine:   nohup ./run_gls.sh -m sdf &
###############################################################################
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths (all relative to this script, so it works from any clone location)
# ---------------------------------------------------------------------------
GLS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$GLS_DIR/../.." && pwd)
ASIC_DIR="$REPO_ROOT/ASIC"

TOP=soc_netlist_tb                       # module name inside tb/gls_tb.sv
DUT_SCOPE="$TOP.dut"                     # SDF top = soc_synth_top instance

PNR_NETLIST="$ASIC_DIR/innovus/out/soc/soc_pnr_netlist.v"
GENUS_NETLIST="$ASIC_DIR/genus/out/soc/soc_netlist.v"
SDF_FILE="${SDF_FILE:-$ASIC_DIR/innovus/out/soc/soc.sdf}"

CELL_PRIMS="$ASIC_DIR/sky130_ref/primitives.v"
CELL_LIB="$ASIC_DIR/sky130_ref/sky130_fd_sc_hd.v"
SRAM_MODEL="$REPO_ROOT/RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v"

SOC_IF="$REPO_ROOT/RTL/SoC/soc_interface.sv"
FLASH_MODEL="$REPO_ROOT/RTL/memory/spi_flash_model.sv"
CORE_PROBE="$GLS_DIR/tb/core_probe.sv"
GLS_PKG="$GLS_DIR/tb/gls_package.sv"
TB_TOP="$GLS_DIR/tb/gls_tb.sv"

PROG_DIR="$GLS_DIR/program"
PROG_NAME=gls_test                       # tb does $readmemh("gls_test.hex")
IMAGE_WORDS=40                           # generator sends image_size=160 bytes

RISCV_PREFIX="${RISCV_PREFIX:-riscv64-unknown-elf-}"

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
MODE=func; NETSEL=pnr; HEX_IN=""; WAVES=0; GUI=0; CLEAN=0; MTM=max
usage() { sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while getopts "m:t:n:x:wgch" opt; do
    case $opt in
        m) MODE=$OPTARG ;;
        t) MTM=$OPTARG ;;
        n) NETSEL=$OPTARG ;;
        x) HEX_IN=$(cd "$(dirname "$OPTARG")" && pwd)/$(basename "$OPTARG") ;;
        w) WAVES=1 ;;
        g) GUI=1 ;;
        c) CLEAN=1 ;;
        h) usage 0 ;;
        *) usage 1 ;;
    esac
done

case $MODE   in func|sdf) ;; *) echo "ERROR: -m must be func or sdf" >&2; exit 1 ;; esac
case $MTM    in
    max) MTM_CONTROL=MAXIMUM ;;
    min) MTM_CONTROL=MINIMUM ;;
    *) echo "ERROR: -t must be max or min" >&2; exit 1 ;;
esac
case $NETSEL in
    pnr)   NETLIST=$PNR_NETLIST ;;
    genus) NETLIST=$GENUS_NETLIST ;;
    *) echo "ERROR: -n must be pnr or genus" >&2; exit 1 ;;
esac
if [[ $MODE == sdf && $NETSEL == genus ]]; then
    echo "ERROR: SDF mode only makes sense with the post-route (pnr) netlist" >&2; exit 1
fi

if [[ $MODE == sdf ]]; then
    RUN_DIR="$GLS_DIR/sim/${MODE}${MTM}_${NETSEL}"   # sim/sdfmax_pnr, sim/sdfmin_pnr
else
    RUN_DIR="$GLS_DIR/sim/${MODE}_${NETSEL}"
fi

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
command -v xrun >/dev/null 2>&1 || die "xrun not in PATH -- load Xcelium first (e.g. 'module load xcelium' or source the lab cshrc)"

# Some installs put a 32-bit xrun wrapper first on PATH. On a host without the
# 32-bit loader/libs (glibc.i686) it fails with "No such file or directory".
# If xrun can't start, switch to the 64-bit binaries in the sibling 64bit/ dir
# (covers xrun, xmsdfc and the tools xrun launches). This only changes PATH for
# this script's run -- nothing on the lab machine is modified.
if ! xrun -version >/dev/null 2>&1; then
    XRUN_ON_PATH=$(command -v xrun)
    XRUN_64DIR=""
    for d in "$(dirname "$XRUN_ON_PATH")/64bit" \
             "$(dirname "$(readlink -f "$XRUN_ON_PATH")")/64bit"; do
        if [[ -x $d/xrun ]]; then XRUN_64DIR=$d; break; fi
    done
    [[ -n $XRUN_64DIR ]] || die "xrun at $XRUN_ON_PATH won't start (likely a 32-bit binary without 32-bit libs)
       and no 64bit/xrun was found next to it. Put Xcelium's tools/bin/64bit first in PATH,
       or ask an admin to install glibc.i686."
    export PATH="$XRUN_64DIR:$PATH"
    export CDS_AUTO_64BIT=ALL
    hash -r
    xrun -version >/dev/null 2>&1 || die "64-bit xrun at $XRUN_64DIR/xrun also fails to start -- check the Xcelium install / license setup"
    echo "NOTE: $XRUN_ON_PATH won't start here; using 64-bit Xcelium from $XRUN_64DIR"
fi
echo "=== Using $(command -v xrun): $(xrun -version 2>&1 | head -1) ==="
for f in "$NETLIST" "$CELL_PRIMS" "$CELL_LIB" "$SRAM_MODEL" "$SOC_IF" "$FLASH_MODEL" \
         "$CORE_PROBE" "$GLS_PKG" "$TB_TOP"; do
    [[ -f $f ]] || die "missing file: $f"
done
if [[ $MODE == sdf ]]; then
    [[ -f $SDF_FILE ]] || die "missing SDF: $SDF_FILE
       Write it from the saved Innovus database (no need to redo P&R):
         cd $ASIC_DIR/innovus && DESIGN=soc innovus -nowin -files write_sdf.tcl -log logs/write_sdf_soc.log"
    [[ $SDF_FILE -nt $NETLIST ]] || echo "WARNING: SDF is older than the netlist -- re-export it so they match"
fi

[[ $CLEAN == 1 ]] && rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

# ---------------------------------------------------------------------------
# Program image -> gls_test.hex (one 32-bit word per line, padded to 160 bytes)
#   We go through a raw binary instead of 'objcopy -O verilog' so the word
#   values (not byte order) are exactly what $readmemh expects, and pad with
#   NOPs so the tb never shifts X bytes into the UART.
# ---------------------------------------------------------------------------
HEX="$RUN_DIR/$PROG_NAME.hex"
if [[ -n $HEX_IN ]]; then
    [[ -f $HEX_IN ]] || die "hex not found: $HEX_IN"
    cp "$HEX_IN" "$HEX"
elif [[ -f $PROG_DIR/$PROG_NAME.hex ]]; then
    cp "$PROG_DIR/$PROG_NAME.hex" "$HEX"
else
    command -v "${RISCV_PREFIX}as" >/dev/null 2>&1 || die "no $PROG_NAME.hex and no RISC-V toolchain (${RISCV_PREFIX}as).
       Either build the hex on a machine that has it and pass -x <file>,
       or set RISCV_PREFIX (e.g. RISCV_PREFIX=riscv32-unknown-elf-)."
    echo "=== Building $PROG_NAME.hex from program/$PROG_NAME.s ==="
    "${RISCV_PREFIX}as" -march=rv32i -mabi=ilp32 "$PROG_DIR/$PROG_NAME.s" -o $PROG_NAME.o
    "${RISCV_PREFIX}ld" -m elf32lriscv -T "$PROG_DIR/${PROG_NAME}_linker.ld" $PROG_NAME.o -o $PROG_NAME.elf
    "${RISCV_PREFIX}objcopy" -O binary $PROG_NAME.elf $PROG_NAME.bin
    # od -tx4 prints host-endian words; lab Linux (x86) is little-endian like RV32
    od -An -v -tx4 -w4 $PROG_NAME.bin | tr -d ' ' | sed '/^$/d' > "$HEX"
    n=$(wc -l < "$HEX")
    (( n <= IMAGE_WORDS )) || die "program is $n words but the tb only sends $IMAGE_WORDS (image_size=160)"
    for (( i = n; i < IMAGE_WORDS; i++ )); do echo 00000013 >> "$HEX"; done   # addi x0,x0,0
    echo "    $n instruction words, padded to $IMAGE_WORDS"
fi
words=$(grep -cvE '^\s*(@|//|$)' "$HEX" || true)
(( words >= IMAGE_WORDS )) || echo "WARNING: $HEX has $words words (< $IMAGE_WORDS) -- the tb will send X bytes for the rest"

# ---------------------------------------------------------------------------
# Build the xrun command
# ---------------------------------------------------------------------------
XRUN_ARGS=(
    -64bit
    -top "$TOP"
    -timescale 1ns/1ps              # for files with no `timescale (SRAM model, interface)
    -incdir "$GLS_DIR/tb"           # gls_package: `include "./test_classes/..."
    -incdir "$GLS_DIR/tb/test_classes"  # `include "../../../../RTL/memory/macros.vh"
    -define "UNIT_DELAY=#1"
    -licqueue
    -status
    -l xrun.log
)

if [[ $MODE == func ]]; then
    # FUNCTIONAL picks the sky130 models without specify blocks
    XRUN_ARGS+=( -define FUNCTIONAL -nospecify -notimingchecks )
else
    # Timing views (specify blocks) + SDF. Compile the SDF once, reuse it.
    SDF_X="$RUN_DIR/$(basename "$SDF_FILE").X"
    if [[ ! -f $SDF_X || $SDF_FILE -nt $SDF_X ]]; then
        echo "=== Compiling SDF: $SDF_FILE ==="
        xmsdfc "$SDF_FILE" -output "$SDF_X"
    fi
    cat > sdf.cmd <<EOF
COMPILED_SDF_FILE = "$SDF_X",
SCOPE = $DUT_SCOPE,
LOG_FILE = "$RUN_DIR/sdf_annotate.log",
MTM_CONTROL = "$MTM_CONTROL",
SCALE_TYPE = "FROM_MTM";
EOF
    XRUN_ARGS+=(
        -sdf_cmd_file sdf.cmd
        -neg_tchk                   # sky130 $setuphold uses delayed CLK/D nets
        -sdf_verbose
    )
fi

if [[ $GUI == 1 ]]; then
    XRUN_ARGS+=( -access +rwc -gui )
elif [[ $WAVES == 1 ]]; then
    cat > waves.tcl <<EOF
database -open waves -shm -into waves.shm -default
probe -create $TOP -depth all -all -shm -database waves
run
exit
EOF
    XRUN_ARGS+=( -access +rwc -input waves.tcl )
fi

# Compile order: cell models -> SRAM model -> netlist -> interfaces -> flash model -> tb package -> tb top
# (.v files are parsed as plain Verilog, .sv as SystemVerilog -- do NOT add -sv)
FILES=(
    "$CELL_PRIMS"
    "$CELL_LIB"
    "$SRAM_MODEL"
    "$NETLIST"
    "$SOC_IF"
    "$CORE_PROBE"
    "$FLASH_MODEL"
    "$GLS_PKG"
    "$TB_TOP"
)

echo "=== GLS: mode=$MODE  netlist=$(basename "$NETLIST")  run dir=$RUN_DIR ==="
printf '%q ' xrun "${XRUN_ARGS[@]}" "${FILES[@]}" > xrun.cmd; echo >> xrun.cmd
set +e
xrun "${XRUN_ARGS[@]}" "${FILES[@]}"
rc=$?
set -e

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
LOG="$RUN_DIR/xrun.log"
echo
echo "================================ GLS SUMMARY ================================"
echo "log:              $LOG"
# tb $error calls show up as "*E,ASRTST"; everything else with *E is a tool error
tb_err=$(grep -c '\*E,ASRTST' "$LOG" || true)
tool_err=$(grep '\*E,' "$LOG" | grep -vc 'ASRTST' || true)
tviol=$(grep -cE 'Timing violation' "$LOG" || true)
sb_line=$(grep -E 'Total Errors:' "$LOG" | tail -1 || true)
echo "tool errors:      $tool_err"
echo "tb \$error count:  $tb_err"
if [[ $MODE == sdf ]]; then
    echo "SDF delays:       $MTM_CONTROL"
    echo "timing viol msgs: $tviol"
    echo "SDF annotation:   $RUN_DIR/sdf_annotate.log"
    # xmelab prints per-category annotation coverage; show it so a silent
    # non-annotation (0% path delays) is visible
    grep -iE 'SDF statistics|Annotated *=' "$LOG" | sed 's/^/                  /' || true
else
    tviol=0   # timing checks are off in func mode
fi
echo "scoreboard:       ${sb_line:-<not reached>}"
sb_n=$(sed -E 's/.*Total Errors:[[:space:]]*([0-9]+).*/\1/' <<<"$sb_line")
if [[ $rc == 0 && $tool_err == 0 && $tb_err == 0 && $tviol == 0 && -n $sb_line && $sb_n == 0 ]]; then
    echo "RESULT:           PASS"
else
    echo "RESULT:           FAIL (xrun exit $rc)"
    [[ $rc == 0 ]] && rc=1
fi
echo "============================================================================="
exit "$rc"
