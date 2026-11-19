#!/usr/bin/env bash
set -e

# --- Arch Linux Fix 1: Force POSIX locale ---
# Prevents glibc UTF-8 string collation crashes in Vivado
export LC_ALL=C
export LANG=C

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$SCRIPT_DIR/sim_build"

# --- Arch Linux Fix 2: Sourcing Vivado in Arch ---
if ! command -v xvlog &> /dev/null; then
    if [ -f "/opt/Xilinx/2025.2/Vivado/settings64.sh" ]; then
        source /opt/Xilinx/2025.2/Vivado/settings64.sh
    elif [ -f "/tools/Xilinx/2025.2/Vivado/settings64.sh" ]; then
        source /tools/Xilinx/2025.2/Vivado/settings64.sh
    else
        echo "ERROR: 'xvlog' not found in PATH." >&2
        exit 1
    fi
fi

# Paths to your local copies of the files:
CELLS_DIR="$SCRIPT_DIR/../../../ASIC/sky130_ref"  # Where you placed primitives.v & sky130_fd_sc_hd.v
NETLIST="$SCRIPT_DIR/../../../ASIC/genus/out/soc/soc_netlist.v"
SRAM_MODEL="$SCRIPT_DIR/../../../RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v"

SOC_IF="$SCRIPT_DIR/../../../RTL/SoC/soc_interface.sv"
CORE_PROBE="$SCRIPT_DIR/test_classes/core_probe.sv"
FLASH_MEM="$SCRIPT_DIR/../../../RTL/memory/spi_flash_model.sv"
TEST_PKG="$SCRIPT_DIR/test_package.sv"
TB_TOP="$SCRIPT_DIR/soc_netlist_tb.sv"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== [1/3] Compiling Sky130 Library and Netlist ==="
# Plain Verilog mode (NO -sv flag! Prevents parsing corruption)
xvlog -d FUNCTIONAL -d "UNIT_DELAY=#1" \
    "$CELLS_DIR/primitives.v" \
    "$CELLS_DIR/sky130_fd_sc_hd.v" \
    "$SRAM_MODEL" \
    "$NETLIST"

echo "=== [2/3] Compiling Interfaces and Testbench ==="
xvlog -sv \
    "$SOC_IF" \
    "$CORE_PROBE" \
    "$FLASH_MEM" \
    "$TEST_PKG" \
    "$TB_TOP"

echo "=== [3/3] Elaborating Design with xelab ==="
# --- Arch Linux Fix 3: '-mt off' ---
# Multi-threading in xelab crashes with SIGSEGV under modern glibc on Arch.
# Disabling multi-threading (-mt off) stops the segfault completely.
xelab -mt off -L uvm -uvm_version 1.2 -relax -debug typical \
    -top soc_netlist_tb \
    -snapshot soc_gls_sim

echo "=== Build Complete! Launching Simulation... ==="
if [[ "$1" == "--gui" || "$1" == "-g" ]]; then
    xsim soc_gls_sim --gui &
else
    xsim soc_gls_sim -R
fi