#!/bin/bash
# Open-source logic equivalence check (RTL vs Genus netlist) with Yosys EQY.
# Replaces Conformal LEC, which we don't have.
#
# Usage:   bash eqy/run_eqy.sh <design>     e.g. bash eqy/run_eqy.sh gpio
#          bash eqy/run_eqy.sh all          every design in ../config.tcl that has a netlist
#
# Designs, filelists, libraries and output folders come from ../config.tcl
# (the same file run_genus.tcl uses); EQY-only settings are in eqy/config.tcl.
#
# Needs OSS CAD Suite on PATH (yosys, eqy, sby, yices and the slang plugin):
#   source /tapeout/lec_tool/oss-cad-suite/environment

set -e

if [ -z "$1" ]; then
    echo "Usage: bash $0 <design>|all" >&2
    exit 1
fi

export EQY_DESIGN=$1
export EQY_DIR=$(cd "$(dirname "$0")" && pwd)
export GENUS_DIR=$(cd "$EQY_DIR/.." && pwd)
export REPO_ROOT=$(cd "$GENUS_DIR/../.." && pwd)

command -v eqy >/dev/null 2>&1 || {
    echo "ERROR: eqy not on PATH (source oss-cad-suite/environment first)" >&2
    exit 1
}

# Run the Tcl driver with tclsh if it's installed, otherwise with Yosys' built-in Tcl.
if command -v tclsh >/dev/null 2>&1; then
    exec tclsh "$EQY_DIR/run_eqy.tcl"
else
    exec yosys -q -c "$EQY_DIR/run_eqy.tcl"
fi
