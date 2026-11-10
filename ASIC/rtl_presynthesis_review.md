# RTL Pre-Synthesis Review (SoC → Genus / Innovus)

Date: 2026-11-09 · Branch: `diego` @ `0b17217`
Scope: everything `soc.sv` instantiates (core, debug_controller_v2, uart_rec/trans,
bootloader, spi_shift, gpio, SRAM wrappers) plus the Genus setup. Nothing was changed.

How these were found:
- Manual read of every RTL file.
- `xvlog` / `xelab` (Vivado 2024.1) on the SoC compile order, elaborated through a
  minimal wrapper TB.
- `slang -Weverything` with dataflow analysis (latch / undriven / unused checks),
  as a second opinion where xsim is quiet.

Severity:
- **CRIT**: will break the chip or the synthesis run.
- **HIGH**: very likely a functional or synthesis problem.
- **MED**: should be fixed before tapeout.
- **LOW**: cleanup or lint noise.

---

## CRITICAL

| # | Location | Issue |
|---|----------|-------|
| C1 | `RTL/io/debug_controller_v2.sv` (65, 66, 69, 74, 215, 218, 219, 374) | **No reset anywhere.** Every state register relies on a declaration initializer (`= DEBUG_OFF`, `= 0`), and Genus ignores those for ASIC. At power-up `debug_state`, `debug_command`, the rx/tx FSMs and the counters come up random. `debug_command` feeds `soc.sv:157`. If it powers up as `0x05` (FLASH_WRITE), the core is held in reset and the ROM is muxed to the debug port. |
| C2 | `RTL/io/debug_controller_v2.sv:111` (and 120, 149, 173…) | **Latch on `halt`.** It is not assigned in `PROP_DELAY` or `default`, so a latch drives `core_halt`, which is the core's main stall control. |
| C3 | `RTL/io/debug_controller_v2.sv` 108, 284, 285, 314, 386, 397 | **More inferred latches** (confirmed by slang): `flash_write_en`, `data_address`, `write_data`, `debug_rx_done`, `debug_tx_done`, `uart_trans_if.byte_data`. `data_address` and `write_data` feed the ROM address and data mux in `soc.sv`. |
| C4 | `RTL/SoC/soc.sv:133-136` → `RTL/io/gpio.sv:41,51` | **`gpio_if.rst_n` is never driven.** GPIO resets on an undriven net. Genus will tie it off or flag it, and if it resolves to 0 the GPIO stays in reset forever. |
| C5 | `RTL/SoC/soc.sv:177-190` → `RTL/io/gpio.sv:54` | **`io_if.sel` is never driven.** GPIO writes are gated by `bus.sel && bus.we`, so DIR/OUT can never be written. Synthesis will constant-fold both registers to 0, and `gpio_out`/`gpio_oe` will be stuck at 0. |
| C6 | `RTL/SoC/soc.sv:148-174` | **The core reset is combinational.** `core0_if.rst_n` is decoded from `boot_done` and `debug_if.command == FLASH_WRITE`, so any glitch on the 8-bit compare resets the core. It is also not synchronized to the clock. It should come from a flop. |
| C7 | `ASIC/genus/config.tcl` | **The Genus flow can't build the SoC yet.** `TOP_OF` only lists `alu` (no `core` or `soc`, though `filelists/core.f` exists). There is no `soc.f`. `EXTRA_LIBS` is empty, so the sky130 SRAM macro `.lib` is never read. Without the `.lib`, Genus will try to synthesize the behavioral OpenRAM model or leave it unresolved. |

## HIGH

| # | Location | Issue |
|---|----------|-------|
| H1 | `RTL/core/branch_unit.sv:27` | **Latch on `branch_logic_out`.** The `default:` arm assigns `bu_if.output_flag` instead of `branch_logic_out`, so funct3 = `3'b011` holds the previous value. slang missed this one; it was found by hand. |
| H2 | `RTL/io/debug_controller_v2.sv:58,60` | **Use-before-declaration.** `debug_command` and `halt` are used in the `always_comb` at line 55 but declared at lines 69/72. slang reports a hard **error**; xsim accepts it silently. Genus may error or bind them as implicit nets. |
| H3 | `RTL/io/debug_controller_v2.sv:51-52` | **UART `CLK_RATE` is hardcoded to 100 MHz.** At 80 MHz the bit period is 25% too long (about 7680 baud instead of 9600), so the UART link will fail. |
| H4 | `RTL/io/uart_trans.sv` 46, 60, 64-65, 79 | **Blocking and nonblocking assignments are mixed on the same variables** (`uart_state = …` and `uart_state <= …`; `bit_counter = …` and `<= …`) inside `always_ff`. Genus may error on this, and it is a sim/synth mismatch risk. |
| H5 | `RTL/io/debug_controller_v2.sv:222` | **Blocking assignment in `always_ff`** (`debug_rx_state = next_debug_rx_state;`). The case statement below then reads the *new* value, so the register behaves differently from the other FSMs. |
| H6 | `RTL/io/uart_rec.sv:30-33` | **RX synchronizer is effectively 1 flop.** `serial_in` and `serial_in_extra` both sample the raw pin, and `serial_in_extra` is never used. The FSM reads a single-flop sample of an async input, which is a metastability risk. |
| H7 | `RTL/io/uart_rec.sv`, `RTL/io/uart_trans.sv` | **No reset; relies on initializers** (`uart_state = IDLE`, `serial_out = 1'b1`, …). In silicon `tx` can power up low (a spurious start bit), and gate-level sim will show X. |
| H8 | `RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v:64,82` | **The OpenRAM behavioral model fails a strict compile** ("`mem` used before declaration"). It only builds with `xvlog --relax`. It is a **sim-only model**: keep it out of synthesis filelists and use the macro `.lib`/`.lef` instead. |

## MEDIUM

| # | Location | Issue |
|---|----------|-------|
| M1 | `RTL/SoC/soc.sv:139-140`, `RTL/io/bootloader.sv:162` | **The external `rst_n` goes straight into synchronous-reset flops with no reset synchronizer.** Only the bootloader and SPI blocks use it at all. The debug controller, UARTs and GPIO have no reset (see C1, C4, H7). |
| M2 | `RTL/SoC/soc.sv:118,121,133,139`; `RTL/core_top_level/core.sv:184`; `RTL/io/debug_controller_v2.sv:56-57` | **Clocks are routed through `always_comb` into interfaces.** In synthesis these are just wires. In RTL sim, each hop adds a delta cycle: the core, register file, UART and GPIO flops see `clk` one or two deltas after the SRAMs (which take `soc_if.clk` directly), which can cause sim races. Use `assign`, or the port directly. |
| M3 | `RTL/SoC/soc.sv:161` | **Width truncation:** `rom_address (13b) = debug_if.data_address (32b)`. Also `core.sv:335` and `core.sv:343` (32→13 on `memory_address`). These are probably intended, but they will show up as Genus warnings. |
| M4 | `RTL/memory/data_memory_sram2k.sv:34` + `RTL/SoC/soc.sv:177` | **The RAM window is 4 KB (bit 12 = 0), but only 2 KB is populated.** Addresses 0x800–0xFFF select no bank (`csb0=1`), and loads return stale `dout`. |
| M5 | `RTL/memory/instruction_memory_sram6k.sv:36-38,101` | `bank_sel == 3` (0x1800–0x1FFF) selects no macro, so the read mux falls to `dout0_2` and returns stale data. |
| M6 | `RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v:105-108` | **SRAM read timing.** The macro latches on posedge and drives `dout` after negedge + delay, so the path from `dout` into core logic gets roughly half a cycle (~6.25 ns at 80 MHz). Check this against the macro `.lib` in Genus and Innovus. |
| M7 | `RTL/io/bootloader.sv:26` | `POWERUP_CYCLES = 2000` is the sim value (25 µs at 80 MHz). Set it from the flash datasheet's power-up time for silicon. |
| M8 | `RTL/io/bootloader.sv:35,67`; `RTL/SoC/soc.sv:40,154,163` | **Dead or incomplete logic.** `mem_rdata`/`boot_read` is unused. `write_state` and `wrtite_next_state` are declared but never driven or read. The `IDLE`/`FLASH_WRITE` bootloader states are empty placeholders. |
| M9 | `RTL/interfaces/debug_interface_v2.sv:19-20`; `RTL/SoC/soc.sv` | `flash_write_done` is never driven and `flash_write_en` is never read, so the flash-write path is unfinished. `debug_if.write_en` only reaches the ROM in `FLASH_WRITE` mode. |
| M10 | `RTL/SoC/soc.sv:16` | `soc` takes `soc_interface` **without a modport**, so the ports have no direction. A top-level interface port also produces flattened port names in Genus. Add a flat-port wrapper (like `core_synth_top.sv`) for pad hookup. |
| M11 | `RTL/io/debug_controller_v2.sv:312` | The rx-FSM `unique case` has no `default`, and `RECIEVE_DATA` and encoding 3'd7 are unhandled. `next_debug_rx_state` is unassigned there, which is a latch or X risk. |

## LOW / CLEANUP

| # | Location | Issue |
|---|----------|-------|
| L1 | `RTL/SoC/soc.sv:146` | `$monitor` inside `always_comb` re-arms on every evaluation. It is sim-only noise; Genus ignores it with a warning. |
| L2 | `RTL/core_top_level/core.sv:99-113` | `$strobe` in `always_ff` (guarded by `DEBUG_PRINT`). Genus ignores it with a warning. |
| L3 | `RTL/memory/macros.vh` | **No include guard**, and it is included by `soc.sv`, `core.sv` and both SRAM wrappers, so Genus will report macro redefinition warnings. The comments are stale ("10-bit", `MEM_DEPTH 256`, `RAM_DEPTH 128`). |
| L4 | `RTL/core/branch_unit.sv:7-13`, `RTL/core/sign_extender.sv:7-15` | Global `` `define``s with generic names (`` `ALU``, `` `LOAD``, `` `STORE``, `` `JAL``, `` `BEQ``…) leak into every file read afterwards in the same `read_hdl`. Prefer localparams. |
| L5 | `RTL/memory/data_memory_sram2k.sv:23-28` | `bank_sel_q` is registered but never used, so it is a dead flop. |
| L6 | `RTL/memory/*_sram*.sv` | Port 1 is unused (`csb1=1`, `dout1()` open), but `addr1` is still driven by `bank_addr`. Tie it to 0 to save toggling. `csb0` is active on every cycle, so the SRAM reads continuously. |
| L7 | `RTL/io/uart_rec.sv:20`, `RTL/io/uart_trans.sv:16` | `clk_counter` is 32 bits but needs about 14, wasting flops. `HALF_BIT` is unused in `uart_trans`. |
| L8 | `RTL/io/debug_controller_v2.sv:218-219` | `address_index` and `image_bytes` are 32 bits each, but only 13 bits are used. |
| L9 | `RTL/core/register_file.sv` | 32×32 flops with no reset, so reads of uninitialized registers are X in gate-level sim. This is fine functionally. |
| L10 | `RTL/core/decoder.sv` | `imm_type`, `mem_read` and `illegal_instr` are generated but never consumed, so Genus will remove them. Illegal instructions are silently ignored. |
| L11 | `RTL/core_top_level/core.sv:10-12`, `RTL/SoC/soc.sv:13`, `RTL/memory/*_sram*.sv:10` | Unused parameters: `MEM_DEPTH`, `ROM_INITIAL_FILE`, `RAM_INITIAL_FILE`, `GPIO_WIDTH`. |
| L12 | `RTL/SoC/soc.sv:46-49` | Unused nets: `gpio_address`, `gpio_write_en`, `gpio_write`, `gpio_read`. |
| L13 | `RTL/core_top_level/core.sv:38-39,44` | Declaration initializers on `pc`, `pc_next` and `clk_delay`. `pc_next` is also driven by `always_comb`. These are harmless (reset covers them) but some tools warn. |
| L14 | soc, core, debug_controller_v2 | `debug_command_t` is copy-pasted in three files. Put it in a package so the encodings can't drift. |
| L15 | `RTL/io/debug_controller_v2.sv:253` | Stray `;` after `begin`. |
| L16 | xelab | **Missing `` `timescale``** on `soc_interface`, `alu_interface`, `branch_unit_interface`, `debug_interface_v2` and the SRAM model. Strict `xelab` errors on this (XSIM 43-4099), so it only elaborates with `-relax`. |

## Files that must NOT go into a synthesis filelist

| File | Reason |
|------|--------|
| `RTL/io/flash_write.sv` | Empty, and references a nonexistent `flash_write_interface` (compile error). |
| `RTL/io/debug_controller.sv` + `RTL/interfaces/debug_interface.sv` | Old v1, not instantiated. |
| `RTL/io/spi_master.sv` | Not instantiated; the bootloader drives `spi_shift` directly. |
| `RTL/memory/address_decoder.sv`, `RTL/memory/io_decoder.sv` + their interfaces | Not instantiated; `soc.sv` does its own mux. |
| `RTL/memory/data_memory.v`, `instruction_memory.v`, `data_memory_sram8k.v` | Legacy and unused. |
| `RTL/memory/tb_data_memory_sram8k.v` | A testbench sitting in `RTL/`. |
| `RTL/memory/spi_flash_model.sv`, `RTL/memory/sky130_sram_2kbyte_1rw1r_32x512_8.v` | Sim models. Use the macro `.lib`/`.lef`/`.gds`. |
| `RTL/interfaces/clk_interface.sv` | Contains `#` delays; TB only. |
| `RTL/core_top_level/system.sv` | Not used by `soc`. |

## Suggested order to tackle

1. Add resets to debug_controller_v2 and the UARTs (C1, H7), and drive `gpio_if.rst_n` and `io_if.sel` (C4, C5).
2. Kill the latches (C2, C3, H1, M11) and fix the blocking assignments (H4, H5).
3. Register the core reset and add a reset synchronizer (C6, M1).
4. Fix the UART clock rate (H3) and add a second RX synchronizer flop (H6).
5. Build `soc.f`, add a SoC wrapper and the SRAM `.lib` to Genus (C7, M10, H8).
6. Then work through MED and LOW.
