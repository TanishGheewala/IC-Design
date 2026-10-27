# ASIC/innovus — Place & Route (Innovus)

Person 2 half of the ASIC flow. Takes the Genus handoff
(`ASIC/genus/out/<design>/<design>_netlist.v` + `<design>.sdc`) and runs it
through Cadence **Innovus** to a routed, verified **GDSII**.

## Files

| File | What it is |
|------|------------|
| `config.tcl` | All paths and knobs: PDK location, LEF/LIB, SRAM macro, floorplan utilization, power nets. Edit this, not the flow. |
| `run_innovus.tcl` | The flow itself: init → floorplan → SRAM place → power → place → CTS → route → timing → verify (DRC + connectivity) → GDS/netlist/SPEF out. |
| `run_innovus.sh` | One-line launcher. |

## How to run (on the lab Linux machine, where Innovus + the PDK live)

```sh
cd ASIC/innovus
./run_innovus.sh alu        # first milestone: ALU only (no SRAM)
# then, once the core netlists are synthesized:
./run_innovus.sh core
./run_innovus.sh system     # contains SRAM
./run_innovus.sh soc        # full chip, contains SRAM
```

Outputs land in `out/<design>/` (GDS, DEF, SPEF, netlist), reports in
`reports/<design>/`, the saved database in `dbs/<design>/`, and the full tool
log in `logs/innovus_<design>.log`. All of these are git-ignored.

### Prerequisites (on the lab machine — I can't do these from a laptop)

1. **Innovus** on `$PATH` and licensed.
2. **open_pdks sky130A** installed. Default path is `/opt/open_pdks/sky130/sky130A`;
   if yours differs: `export PDK_ROOT=/your/path/sky130A`.
3. **SRAM physical views** for `system`/`soc`. The repo only ships the OpenRAM
   `.v` behavioral model; P&R needs the `.lef`, `.lib`, `.gds` from
   [VLSIDA/sky130_sram_macros](https://github.com/VLSIDA/sky130_sram_macros).
   Put them somewhere and point to them:
   `export SRAM_DIR=/path/to/sky130_sram_2kbyte_1rw1r_32x512_8`
   (default looked-up location is `ASIC/macros/sky130_sram_2kbyte_1rw1r_32x512_8/`).
4. The Genus run for that `<design>` must already have produced the netlist + SDC.

## Notes / things to tune

- **ALU has no clock tree.** It's combinational, so `step_cts` detects there are
  no registers and skips — expected.
- **Floorplan** starts at 55% utilization, square. Loosen `TARGET_UTIL` in
  `config.tcl` if placement is congested; tighten it for a denser die.
- **SRAM placement** (`step_place_sram`) auto-finds macros by cell name and
  stacks them up the left edge as a first pass. Once you see the real design,
  replace the coordinate math with explicit `placeInstance` calls per bank.
- **Verify the tech-LEF name.** Some open_pdks installs name it
  `sky130_fd_sc_hd__nom.tlef` (what `config.tcl` assumes); if yours differs,
  fix `TECH_LEF` there.
- To debug interactively: start `innovus`, then
  `set INTERACTIVE 1; source run_innovus.tcl` and call `step_init`,
  `step_floorplan`, … one at a time.
