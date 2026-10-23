set -e
export DESIGN=${1:-alu}
export GENUS_DIR=$(cd "$(dirname "$0")" && pwd)
export REPO_ROOT=$(cd "$GENUS_DIR/../.." && pwd)
mkdir -p "$GENUS_DIR/logs"
cd "$GENUS_DIR"
genus -no_gui -f run_genus.tcl -log "logs/genus_${DESIGN}.log"