# Post-Innovus gate-level simulation (Xcelium)

```
ASIC/gls/
├── run_gls.sh          # <- run this
├── program/            # gls_test.s (+ linker script); hex is built by run_gls.sh
├── tb/                 # testbench (gls_tb.sv = module soc_netlist_tb)
└── sim/<mode>_<net>/   # run output (git-ignored): xrun.log, sdf_annotate.log, waves.shm
```

## Run it (lab Linux machine)

```sh
cd ASIC/gls
./run_gls.sh                # functional GLS, post-route netlist (no delays)
./run_gls.sh -m sdf         # timing GLS with Innovus SDF, max delays (setup)
./run_gls.sh -m sdf -t min  # timing GLS, min delays (hold)
./run_gls.sh -m sdf -w      # + waveforms -> simvision sim/sdfmax_pnr/waves.shm
./run_gls.sh -n genus       # same tb on the post-Genus netlist
./run_gls.sh -h             # all options
```

The run is long (~820 ms of chip time: two UART transfers at 9600 baud), so use
`nohup ./run_gls.sh -m sdf > gls.out 2>&1 &` or `tmux`.

## What it needs

| Input | Where |
|---|---|
| post-route netlist | `ASIC/innovus/out/soc/soc_pnr_netlist.v` |
| SDF (sdf mode only) | `ASIC/innovus/out/soc/soc.sdf` (see below) |
| sky130 cell models | `ASIC/sky130_ref/{primitives.v,sky130_fd_sc_hd.v}` |
| SRAM model | `RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v` |
| tb deps | `RTL/SoC/soc_interface.sv`, `RTL/memory/spi_flash_model.sv` |
| program | `program/gls_test.s` → built with `riscv64-unknown-elf-*` (override with `RISCV_PREFIX=`), or pass `-x my.hex` |

### Getting the SDF

`run_innovus.tcl` now writes `out/<design>/<design>.sdf` in `step_save`. To get one
from the existing database without redoing P&R:

```sh
cd ASIC/innovus
DESIGN=soc innovus -nowin -files write_sdf.tcl -log logs/write_sdf_soc.log
```

## Modes

- **func**: `+define+FUNCTIONAL`, no specify blocks / timing checks. Checks the netlist is logically right.
- **sdf**: sky130 timing views + SDF back-annotation at `soc_netlist_tb.dut`, `-neg_tchk`.
  Setup/hold violations print as `Timing violation` and the flop goes X. Read
  `sdf_annotate.log` first: the SRAM model has no specify block, so warnings
  about the SRAM instances are expected.

PASS means: no `*E` tool errors, no `$error` from the tb, no `Timing violation` (sdf mode), and the scoreboard prints `Total Errors: 0`.
