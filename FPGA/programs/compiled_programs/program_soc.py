import serial
import time

# ==============================================================================
# CONFIGURATION (Verify these match your debug_controller_v2 RTL & setup)
# ==============================================================================
HEX_FILE     = "flash_led_2.hex"
PORT         = "/dev/ttyUSB0"   # Use "/dev/ttyPS1" if running directly on AUP-ZU3 ARM
BAUD_RATE    = 9600             # Must match debug_controller_v2 baud rate

COUNT_WIDTH  = 2                # How many bytes debug_controller_v2 expects for length (1, 2, or 4)
COUNT_ENDIAN = "little"         # "little" or "big" endian for the byte count

BYTE_DELAY   = 0.01             # 10 ms pause between each byte sent
ERASE_WAIT   = 0.10             # Pause after command/count in case flash erases first
BOOT_WAIT    = 2.00             # Wait time for bootloader to finish copying before resume

CMD_HALT     = 0b0000_0001      # 0x01
FLASH_WRITE  = 0b0000_0101      # 0x05
CMD_RESUME   = 0b1111_1111      # 0xFF

# ==============================================================================
# 1. PARSE HEX FILE & COUNT BYTES
# ==============================================================================
raw_bytes = bytearray()

with open(HEX_FILE, "r") as f:
    for line in f:
        # Strip comments (// or #) and whitespace
        clean_line = line.split("//")[0].split("#")[0].strip()
        # Skip empty lines and Verilog @address headers (e.g., @00000000)
        if not clean_line or clean_line.startswith("@"):
            continue
        raw_bytes.extend(bytes.fromhex(clean_line))

byte_count = len(raw_bytes)
print(f"Loaded {byte_count} bytes from {HEX_FILE}")

if byte_count == 0:
    raise ValueError("No bytes found in hex file!")

if byte_count >= (1 << (8 * COUNT_WIDTH)):
    raise ValueError(f"Byte count ({byte_count}) does not fit in {COUNT_WIDTH} byte(s)!")

count_bytes = byte_count.to_bytes(COUNT_WIDTH, byteorder=COUNT_ENDIAN)

# ==============================================================================
# 2. SEND OVER UART
# ==============================================================================
with serial.Serial(PORT, BAUD_RATE, timeout=2) as ser:
    time.sleep(0.05)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # Step 1: Halt CPU
    print("Sending CMD_HALT...")
    ser.write(bytes([CMD_HALT]))
    ser.flush()
    time.sleep(0.5)

    # Step 2: Send FLASH_WRITE command + Byte Count
    print(f"Sending FLASH_WRITE + count ({byte_count} bytes = 0x{count_bytes.hex()})...")
    ser.write(bytes([FLASH_WRITE]))
    time.sleep(BYTE_DELAY)

    for b in count_bytes:
        ser.write(bytes([b]))
        ser.flush()
        time.sleep(BYTE_DELAY)

    # Give flash/controller a moment in case it triggers an erase here
    time.sleep(ERASE_WAIT)

    # Step 3: Stream payload 1 byte at a time with pause between each byte
    print(f"Sending {byte_count} data bytes...")
    for i, b in enumerate(raw_bytes):
        ser.write(bytes([b]))
        ser.flush()
        time.sleep(BYTE_DELAY)
        if (i + 1) % 16 == 0 or (i + 1) == byte_count:
            print(f"  Sent {i + 1}/{byte_count} bytes")

    # Step 4: Wait for flash write & bootloader to finish
    print(f"Waiting {BOOT_WAIT}s for flash/bootloader...")
    time.sleep(BOOT_WAIT)

    # Step 5: Resume CPU
    print("Sending CMD_RESUME...")
    ser.write(bytes([CMD_RESUME]))
    ser.flush()

print("Done!")