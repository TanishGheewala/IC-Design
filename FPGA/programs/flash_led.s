# flash_led.s -- blink the LED on GPIO pin 0 (RV32I, FPGA demo)
#
# GPIO registers (RTL/io/gpio.sv, I/O window selected by address bit 12):
#   0x1000  DIR  1 = pin is an output
#   0x1004  OUT  value driven on output pins
#
# Timing: single-cycle core at 50 MHz -> 1 instruction = 20 ns.
# The delay loop is 2 instructions per pass (addi + bne) = 40 ns, so
#   DELAY_COUNT = 12,500,000 passes -> ~0.5 s per toggle -> LED blinks at ~1 Hz.
# Change DELAY_COUNT to make it blink faster/slower.

.equ GPIO_BASE,   0x00001000
.equ GPIO_DIR,    0x0             # offset from GPIO_BASE
.equ GPIO_OUT,    0x4             # offset from GPIO_BASE
.equ LED_MASK,    0x1             # bit 0 = GPIO port 0
.equ DELAY_COUNT, 12500000        # ~0.5 s at 50 MHz

.global _start
.section .text
_start:
    li   s0, GPIO_BASE            # s0 = GPIO base address
    li   s1, LED_MASK             # s1 = bit for pin 0
    li   s2, DELAY_COUNT          # s2 = delay loop length

    sw   s1, GPIO_DIR(s0)         # make pin 0 an output (other pins stay inputs)
    li   t1, 0                    # t1 = current LED state (start off)

_blink:
    xor  t1, t1, s1               # flip bit 0
    sw   t1, GPIO_OUT(s0)         # drive it on the pin

    mv   t0, s2                   # t0 = delay counter
_delay:
    addi t0, t0, -1
    bne  t0, zero, _delay         # spin until the counter hits 0

    j    _blink                   # toggle again, forever
