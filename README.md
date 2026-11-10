# IC-Design
Project #9: Tapeout-Ready Integrated Circuit Design Using Open-Source PDK

Team: [Tanish Gheewala](https://github.com/TanishGheewala), [Diego Chavez](https://github.com/chavez-diego), [Housain Alsafar](https://github.com/HousainA), [Evan Gilbert](https://github.com/e-tachyon), [Cheng-Huan Lu](https://github.com/chenghuanlu110)

EE 491W – Senior Design A - Spring 2026 
<br>
EE 492 - Senior Design B - Fall 2026

San Diego State University

## Project Details

### Project Overview

This project involves designing a tapeout-ready Application-Specific Integrated Circuit (ASIC) microcontroller using the open-source SkyWater SKY130 PDK. The chip integrates a 32-bit RISC-V RV32I single-cycle CPU, on-chip memory, and external interfaces (JTAG, QSPI, GPIO). The primary deliverable is a verified GDSII file ready for fabrication.

### Specifications
- ISA: RV32I Base Integer Instruction Set
- Microarchitecture: Single-Cycle Datapath
- Process: Skywater SKY130 (130nm)
- Package: 32-pins (JTAG, QSPI, GPIO)

### Prototyping
- Universal Verification Methodology (UVM) Testbench
- FPGA Hardware Prototyping (AUP-ZU3 Zynq UltraScale+)

### Toolchain
- RTL: IcarusVerilog, GTKWave, TerosHDL
- Verification: Testbenching, UVM
- EDA: Vivado, Cadence Virtuoso
