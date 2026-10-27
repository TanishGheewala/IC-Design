#!/usr/bin/env bash
# Launch the Innovus P&R flow.
#   Usage: ./run_innovus.sh <design>      (design = alu | core | system | soc)
#   Default design is "alu" (Person 1's first milestone netlist).
set -e
export DESIGN=${1:-alu}
export INNOVUS_DIR=$(cd "$(dirname "$0")" && pwd)
export REPO_ROOT=$(cd "$INNOVUS_DIR/../.." && pwd)
mkdir -p "$INNOVUS_DIR/logs"
cd "$INNOVUS_DIR"
innovus -no_gui -files run_innovus.tcl -log "logs/innovus_${DESIGN}.log" -overwrite
