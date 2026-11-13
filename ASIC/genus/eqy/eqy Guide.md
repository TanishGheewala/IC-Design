# Running LEC using eqy

1. Ensure Github repo is up to date by running `git pull origin main`
2. `source /tapeout/lec_tool/oss-cad-suite/environment`
3. `cd IC-Design/ASIC/genus`
4. `bash eqy/run_eqy.sh {design name}` (or `bash eqy/run_eqy.sh all` for every design that has a netlist)
    - Design names are the ones in `genus/config.tcl` (`alu`, `core`, `gpio`, `debugcon`, `soc`)
    - Run Genus for the design first (`bash run_genus.sh {design name}`); eqy compares the RTL against `out/{design name}/{design name}_netlist.v`

**Reports**

1. **Summary table**: printed at the end of the run and saved to `eqy/work/{design name}/eqy_summary.rpt`
    - `EQ` / `NON-EQ`: number of partitions (pieces of the design) proven / not proven equivalent. `NON-EQ` should be 0 or very minimal, our targe is min 95% EQ
    - Non-equivalent partitions are listed by name under the table
2. **eqy log**: `genus/reports/{design name}/{design name}_eqy.log`
    - Full log of the run, this is where we look for details on ERRORS
    - This is the copy to commit; everything under `eqy/work/` is under a git ignore
3. **Detailed run folder**: `eqy/work/{design name}/`
    - `gold` = RTL, `gate` = Genus netlist. Their logs show problems reading either design
    - `strategies/` has the proof log for each partition, only needed when one is `NON-EQ`
    - `eqy/work/{design name}.out` is the raw terminal output of the run

**Common errors**

- `Found logic loop` / `check -assert` error: a combinational loop in the RTL, usually an `always_comb` that doesn't assign a signal in every case (a latch). The loop message names the wire. Fix the RTL, rerun Genus, then rerun eqy
- `no netlist` (SKIPPED): Genus hasn't been run for that design yet
- `eqy not on PATH`: step 2 was skipped in this terminal
