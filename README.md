# Microcontroller Unit IC Design
**Project #9: Tapeout-Ready Integrated Circuit Design Using Open-Source PDK**

A RISC-V microcontroller built from scratch in SystemVerilog and taken from RTL to a fabrication-ready GDSII file using the open-source SkyWater SKY130 (130 nm) PDK.

**Team:** [Tanish Gheewala](https://github.com/TanishGheewala), [Diego Chavez](https://github.com/chavez-diego), [Housain Alsafar](https://github.com/HousainA), [Evan Gilbert](https://github.com/e-tachyon), [Cheng-Huan Lu](https://github.com/chenghuanlu110)

EE 491W – Senior Design A – Spring 2026<br>
EE 492 – Senior Design B – Fall 2026<br>
San Diego State University

---

## Overview

The chip is a small, self-contained microcontroller built around a 32-bit **RV32I single-cycle CPU**. At power-up, a hardware **bootloader** copies the program out of an external SPI flash into on-chip instruction SRAM and then releases the core from reset. Software talks to the outside world through memory-mapped **GPIO**. A **UART debug controller** lets a host PC halt the core, read back registers, memory and the PC, and reprogram instruction memory without re-flashing.

```
                    ┌──────────────────────────── soc ─────────────────────────────┐
                    │                                                               │
  SPI flash ◄──────►│ bootloader ──► instruction SRAM (6 KB) ──► ┌───────────────┐ │
 (sclk/mosi/        │                        ▲                    │  RV32I core   │ │
  miso/cs_n)        │                        │ flash write        │ (single-cycle)│ │
                    │                        │                    └──────┬────────┘ │
  UART (rx/tx) ◄───►│ debug controller ──────┴─ halt / resume / read ────┤          │
                    │                                                     │ load/store
                    │                       address decode ◄──────────────┘          │
                    │                        │           │                           │
                    │               data SRAM (2 KB)   I/O window ──► GPIO ─────────►│ gpio[9:0]
                    └───────────────────────────────────────────────────────────────┘
```

## Specifications

| | |
|---|---|
| ISA | RISC-V RV32I base integer instruction set |
| Microarchitecture | Single-cycle datapath |
| Process | SkyWater SKY130 (130 nm), `sky130_fd_sc_hd` standard cells |
| Target clock | 80 MHz (12.5 ns) |
| Instruction memory | 6 KB SRAM, loaded from external SPI flash at boot |
| Data memory | 2 KB SRAM |
| SRAM macros | OpenRAM `sky130_sram_2kbyte_1rw1r_32x512_8` |
| External I/O | SPI (boot flash), UART (debug), 10-bit GPIO, clock, active-low reset |
| HDL | SystemVerilog |

## Architecture

### CPU core (`RTL/core`, `RTL/core_top_level`)
A single-cycle RV32I datapath: instruction decoder, register file, ALU, branch unit, and sign extender. Each block connects through its own SystemVerilog interface (`RTL/interfaces`).

### Memory and address decoding (`RTL/memory`)
- **Instruction SRAM**: the bootloader writes it at power-up, and the debug controller can rewrite it at runtime.
- **Data SRAM**: holds the core's loads and stores.
- **`address_decoder`**: splits the data address space on its top bit. The lower half goes to RAM and the upper half is the memory-mapped I/O window.
- **`io_decoder`**: divides the I/O window into equal, power-of-two peripheral slots, so adding a peripheral is a parameter change.

### Peripherals (`RTL/io`)
- **Bootloader**: an FSM that issues a standard SPI `0x03 READ` to the external flash and streams the image into instruction SRAM. The core stays in reset until `boot_done` is asserted.
- **SPI** (`spi_master`, `spi_shift`): mode 0, MSB first, with a configurable clock divider.
- **GPIO**: 10 pins with a direction register, an output register and a synchronized input register:

  | Offset | Register | Access | Description |
  |---|---|---|---|
  | `0x00` | `DIR` | RW | 1 = output, 0 = input. Resets to all inputs. |
  | `0x04` | `OUT` | RW | Value driven on output pins |
  | `0x08` | `IN`  | RO | Pin levels after a 2-flop synchronizer |

- **UART debug controller** (`debug_controller_v2`, `uart_rec`, `uart_trans`): takes byte commands from a host PC. The commands are halt, resume, return register, return memory, return PC, and flash write (writes to instruction memory).

## Verification

Verification uses a lightweight, UVM-inspired class-based approach. Each testbench has a `_packet.sv` (randomized transaction), a `_test.sv` (driver, checker and scoreboard) and a `_compile_order.csv` for TerosHDL. It does not depend on the UVM library.

| Level | Location | Status |
|---|---|---|
| Submodules: ALU, decoder, register file, branch unit, sign extender, RAM, ROM, address decoder, I/O decoder, GPIO, SPI shift/master, bootloader | `Verification/Submodule_Verification` | ✅ Passing |
| I/O: debug controller | `Verification/io_verification` | ✅ Passing |
| Core: official RISC-V architectural compliance suite (RV32I) | `Verification/Core_Verification/riscv_arch_testbench` | ✅ **39 / 39 tests passed** ([results](Verification/Core_Verification/riscv_arch_testbench/results/production-core-rv32i-results.csv)) |
| Full SoC: boot from SPI flash model, UART debug sequences | `Verification/SoC_Verification` | 🔄 Final verification in progress |
| FPGA hardware validation (AUP-ZU3 Zynq UltraScale+) | `Prototypes/fpga_prototype` | 🔄 In progress |

## ASIC Flow (Cadence)

```
RTL ──► Genus (synthesis) ──► Conformal (LEC) ──► Innovus (floorplan → place → CTS → route) ──► DRC / LVS ──► GDSII
```

- **`ASIC/genus`**: synthesis scripts, per-design filelists, SDC constraints and synthesis wrappers. Run with `./run_genus.sh <design>`.
- **`ASIC/innovus`**: place-and-route flow from the Genus netlist to a routed GDSII, including SRAM macro placement and power planning. Run with `./run_innovus.sh <design>`. See [`ASIC/innovus/README.md`](ASIC/innovus/README.md) for prerequisites.

**First milestone:** the ALU synthesizes cleanly to SKY130 at the 80 MHz target with positive slack, using 908 cells and about 5,550 µm².

| Stage | Status |
|---|---|
| Synthesis flow and constraints | ✅ Set up, ALU synthesized |
| Core and full-SoC synthesis | 🔄 In progress |
| Place and route to GDSII | 🔄 Scripts ready, runs in progress |
| Signoff (DRC, LVS, timing) | ⏳ Upcoming |

## Repository Structure

```
IC-Design/
├── RTL/
│   ├── core/              # CPU datapath blocks (ALU, decoder, register file, ...)
│   ├── core_top_level/    # core.sv, system.sv
│   ├── memory/            # SRAM wrappers, address/I-O decoders, SPI flash model
│   ├── io/                # bootloader, SPI, GPIO, UART, debug controller
│   ├── interfaces/        # SystemVerilog interfaces with modports
│   └── SoC/               # soc.sv chip top level
├── Verification/
│   ├── Submodule_Verification/
│   ├── io_verification/
│   ├── Core_Verification/ # core tests + RISC-V arch compliance suite
│   ├── SoC_Verification/  # full-chip testbench and test programs
│   └── test_programs/
├── ASIC/
│   ├── genus/             # synthesis
│   └── innovus/           # place and route
├── Prototypes/            # FPGA and early UVM prototypes
└── TerosHDL Guide.md
```

## Getting Started

**Simulating:** the testbenches are set up for [TerosHDL](https://terostechnology.github.io/terosHDLdoc/) in VS Code, with Vivado XSIM as the backend (`xvlog → xelab → xsim`). Add a testbench's `_compile_order.csv` to a TerosHDL project, select its top module, and run. [`TerosHDL Guide.md`](TerosHDL%20Guide.md) walks through running `system_tb` step by step. Verilator also works for quick lint and simulation checks.

**ASIC flow:** run on a machine with Cadence Genus/Innovus licenses and `open_pdks` SKY130A installed. Instructions are in [`ASIC/innovus/README.md`](ASIC/innovus/README.md).

## Toolchain

| Purpose | Tools |
|---|---|
| RTL design and simulation | SystemVerilog, Vivado / XSIM, Verilator, Icarus Verilog, GTKWave, TerosHDL |
| Verification | Class-based SystemVerilog testbenches, RISC-V architectural test suite |
| FPGA prototyping | Vivado, AUP-ZU3 (Zynq UltraScale+) |
| Synthesis and P&R | Cadence Genus, Conformal, Innovus |
| PDK | SkyWater SKY130 via open_pdks, OpenRAM SRAM macros |

## License

See [LICENSE](LICENSE).
