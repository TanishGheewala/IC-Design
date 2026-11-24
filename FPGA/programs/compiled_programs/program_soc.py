import serial
import time

# ==============================================================================
# CONFIGURATION
# ==============================================================================
PORT         = "/dev/serial/by-id/usb-Xilinx_JTAG+Serial_88022500034C-if01-port0"
BAUD_RATE    = 9600
HEX_FILE     = "flash_led_2.hex"

COUNT_WIDTH  = 4       # debug_controller_v2 expects 32-bit (4 bytes)
COUNT_ENDIAN = "big"   # BYTE_0 -> rx_word[31:24]

BYTE_DELAY   = 0.005   # 5 ms pause between bytes
BOOT_WAIT    = 2.00    # Wait for BOOTLOAD flash write to finish before resuming

CMD_HALT     = 0x01
CMD_RET_PC   = 0x04
FLASH_WRITE  = 0x05
CMD_RESUME   = 0xFF

# ==============================================================================
# 1. PARSE HEX FILE & WORD-SWAP FOR BIG-ENDIAN rx_word
# ==============================================================================
raw_bytes = bytearray()

with open(HEX_FILE, "r") as f:
    for line in f:
        clean_line = line.split("//")[0].split("#")[0].strip()
        if not clean_line or clean_line.startswith("@"):
            continue
        raw_bytes.extend(bytes.fromhex(clean_line))

if len(raw_bytes) == 0:
    raise ValueError(f"No bytes found in {HEX_FILE}!")

# Pad to a multiple of 4 bytes if needed
while len(raw_bytes) % 4 != 0:
    raw_bytes.append(0x00)

# Reverse each 4-byte little-endian RISC-V instruction so that
# BYTE_0 -> [31:24] ... BYTE_3 -> [7:0] forms the exact 32-bit instruction
tx_payload = bytearray()
for i in range(0, len(raw_bytes), 4):
    tx_payload.extend(raw_bytes[i:i+4][::-1])

byte_count = len(tx_payload)
count_bytes = byte_count.to_bytes(COUNT_WIDTH, byteorder=COUNT_ENDIAN)
print(f"Loaded {byte_count} bytes from {HEX_FILE} (header = 0x{count_bytes.hex()})")

# ==============================================================================
# 2. TRANSFER OVER UART
# ==============================================================================
with serial.Serial(PORT, BAUD_RATE, timeout=1.0) as ser:
    time.sleep(0.05)
    ser.reset_input_buffer()
    ser.reset_output_buffer()

    # Step 1: Halt CPU
    print("Sending CMD_HALT (0x01)...")
    ser.write(bytes([CMD_HALT]))
    ser.flush()
    time.sleep(0.1)

    # Step 2: Verify halt by reading PC (RETURN_PC = 0x04)
    print("Querying PC (0x04)...")
    ser.write(bytes([CMD_RET_PC]))
    ser.flush()
    pc_bytes = ser.read(4)
    if len(pc_bytes) == 4:
        pc_val = int.from_bytes(pc_bytes, byteorder="little")
        print(f"  -> Core HALTED! Current PC = 0x{pc_val:08x}")
    else:
        print(f"  -> No response to RETURN_PC (got {len(pc_bytes)} bytes).")

    # Step 3: Send FLASH_WRITE command + 4-byte Big-Endian byte count
    print(f"Sending FLASH_WRITE (0x05) + count ({byte_count} = 0x{count_bytes.hex()})...")
    ser.write(bytes([FLASH_WRITE]))
    ser.flush()
    time.sleep(BYTE_DELAY)

    for b in count_bytes:
        ser.write(bytes([b]))
        ser.flush()
        time.sleep(BYTE_DELAY)

    # Step 4: Stream word-swapped payload bytes
    print(f"Sending {byte_count} data bytes...")
    for i, b in enumerate(tx_payload):
        ser.write(bytes([b]))
        ser.flush()
        time.sleep(BYTE_DELAY)
        if (i + 1) % 16 == 0 or (i + 1) == byte_count:
            print(f"  Sent {i + 1}/{byte_count} bytes")

    # Step 5: Wait for BOOTLOAD state to write flash and finish
    print(f"Waiting {BOOT_WAIT}s for flash/bootloader...")
    time.sleep(BOOT_WAIT)

    # Step 6: Resume CPU
    print("Sending CMD_RESUME (0xFF)...")
    ser.write(bytes([CMD_RESUME]))
    ser.flush()

print("Done!")