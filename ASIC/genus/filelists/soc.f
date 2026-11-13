# SOC Filelist

# macros
RTL/memory/macros.vh

# core
RTL/interfaces/core_interface.sv
RTL/interfaces/alu_interface.sv
RTL/interfaces/branch_unit_interface.sv
RTL/interfaces/decoder_interface.sv
RTL/interfaces/register_file_interface.sv
RTL/interfaces/sign_extender_interface.sv
RTL/core/alu.sv
RTL/core/branch_unit.sv
RTL/core/decoder.sv
RTL/core/register_file.sv
RTL/core/sign_extender.sv
RTL/core_top_level/core.sv

# gpio
RTL/interfaces/gpio_interface.sv
RTL/interfaces/io_interface.sv
RTL/io/gpio.sv

# debug_controller
RTL/interfaces/debug_interface_v2.sv
RTL/interfaces/uart_interface.sv
RTL/io/uart_rec.sv
RTL/io/uart_trans.sv
RTL/io/debug_controller_v2.sv

# memory
RTL/memory/data_memory_sram2k.sv
RTL/memory/instruction_memory_sram6k.sv

# bootloader
RTL/interfaces/spi_interface.sv
RTL/io/bootloader.sv
RTL/io/spi_shift.sv

# soc
RTL/SoC/soc_interface.sv
RTL/SoC/soc.sv

# wrapper
ASIC/genus/wrappers/soc_synth_top.sv