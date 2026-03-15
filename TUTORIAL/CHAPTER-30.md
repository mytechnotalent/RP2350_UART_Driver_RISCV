# Chapter 30: Full Integration — Build, Flash, Wire, and Test

## Introduction

This final chapter ties every previous chapter together.  We walk through the complete journey: from raw assembly source files to a working UART echo on real hardware.  Every step is explained so you can reproduce the result from scratch.

## Part 1: The Project Structure

```
  RP2350_UART_Driver_RISCV/
  ├── build.bat                    Build script (assembler + linker + UF2)
  ├── clean.bat                    Removes build artifacts
  ├── constants.s                  All .equ definitions (Chapter 22)
  ├── coprocessor.s                ARM coprocessor stub — ret only (Chapter 24)
  ├── delay.s                      Delay function (not used in UART echo)
  ├── gpio.s                       GPIO stubs (not used in UART echo)
  ├── image_def.s                  Boot metadata — picobin block (Chapter 21)
  ├── linker.ld                    Linker script — memory layout (Chapter 19)
  ├── main.s                       Application — echo loop (Chapter 29)
  ├── reset.s                      Reset controller — IO_BANK0 (Chapter 26)
  ├── reset_handler.s              Boot sequence + trap vector (Chapter 24)
  ├── stack.s                      Stack pointer init (Chapter 23)
  ├── uart.s                       UART driver — init + TX + RX (Ch 27-28)
  ├── uf2conv.py                   UF2 conversion tool
  ├── uf2families.json             UF2 family IDs
  ├── vector_table.s               Vector table (Chapter 23)
  └── uart.uf2                     Output binary (flashable)
```

**11 assembly source files**, one linker script, one build script, and one Python UF2 converter produce a single flashable binary.

## Part 2: The Build Pipeline

### Step 1: Assembly

The build script runs the assembler on each source file:

```
  riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 file.s -o file.o
```

| Flag | Meaning |
|---|---|
| `-g` | Include debug information |
| `-march=rv32imac_zicsr` | Target ISA: RV32I base + M (multiply) + A (atomic) + C (compressed) + Zicsr (CSR instructions) |
| `-mabi=ilp32` | ABI: 32-bit int, long, and pointer; soft float |

Each `.s` file becomes a `.o` object file containing machine code and relocation entries.

### Step 2: Linking

```
  riscv32-unknown-elf-ld -T linker.ld -o uart.elf [all .o files]
```

The linker:
1. Reads the linker script to determine memory layout
2. Places `.picobin_block` first at 0x10000000
3. Places `.vectors` after it, aligned to 128 bytes
4. Places all `.text` sections after the vectors
5. Resolves all symbol references (Reset_Handler, UART0_In, etc.)
6. Fills in absolute addresses where relocations were emitted
7. Produces `uart.elf` — a complete executable image

### Step 3: Binary Extraction

```
  riscv32-unknown-elf-objcopy -O binary uart.elf uart.bin
```

Strips all ELF metadata (section headers, symbol tables, debug info) and produces a raw binary — just the bytes that go into flash, starting at offset 0.

### Step 4: UF2 Conversion

```
  python uf2conv.py uart.bin --base 0x10000000 --family 0xe48bff5a --output uart.uf2
```

| Parameter | Value | Meaning |
|---|---|---|
| `--base` | 0x10000000 | Flash address where bytes are placed |
| `--family` | 0xE48BFF5A | RP2350 family ID for UF2 |
| `--output` | uart.uf2 | Output filename |

UF2 (USB Flashing Format) wraps the binary in 512-byte blocks with addressing metadata.  The RP2350 boot ROM understands UF2 natively — when you drag the file to the USB drive, the boot ROM parses each block and writes it to flash.

## Part 3: The Memory Map After Build

After linking, the firmware occupies flash memory like this:

```
  Flash Address   Content                   Source File
  0x10000000      IMAGE_DEF block (32 B)    image_def.s
  0x10000080      Vector table (8 B)        vector_table.s (128-byte aligned)
  0x10000088+     .text code                all .s files
                  ├── Reset_Handler         reset_handler.s
                  ├── Init_Stack            stack.s
                  ├── Init_Trap_Vector      reset_handler.s
                  ├── Default_Trap_Handler  reset_handler.s
                  ├── Init_XOSC            xosc.s
                  ├── Enable_XOSC_Peri_Clock xosc.s
                  ├── Init_Subsystem        reset.s
                  ├── UART_Release_Reset    uart.s
                  ├── UART_Init             uart.s
                  ├── UART0_Out             uart.s
                  ├── UART0_In              uart.s
                  ├── Enable_Coprocessor    coprocessor.s
                  ├── main                  main.s
                  └── (stubs)               gpio.s, delay.s
```

Total firmware size: approximately 500–800 bytes.

RAM usage at runtime:
```
  SRAM Address    Content
  0x20082000      Stack top (sp starts here, grows down)
  0x2007A000      Stack limit (32 KB below top)
```

No global variables.  No heap.  The only RAM used is the stack for function call return addresses.

## Part 4: Hardware Setup

### Required Hardware

1. **Raspberry Pi Pico 2** (RP2350-based board)
2. **USB-to-Serial adapter** (FTDI, CP2102, CH340, or similar) — 3.3 V logic levels
3. **3 jumper wires** (female-to-female or as needed)
4. **USB cable** (micro-USB or USB-C to connect Pico 2 to computer)

### Wiring

```
  Pico 2 Pin      Wire      USB-Serial Adapter
  ──────────      ────      ──────────────────
  GP0 (Pin 1)     ────→     RX (receive)
  GP1 (Pin 2)     ←────     TX (transmit)
  GND (Pin 3)     ────→     GND
```

**Critical: TX connects to RX, and RX connects to TX.**  This is a crossover connection — the Pico's transmit pin sends data to the adapter's receive pin, and vice versa.

**Voltage warning:** The RP2350 operates at 3.3 V.  If your USB-serial adapter operates at 5 V, you risk damaging the chip.  Verify your adapter is 3.3 V compatible.

### Pin Reference

On the Pico 2 board, looking at it with the USB connector at the top:

```
  Left side (even GP pins)     Right side (odd GP pins)
  Pin 1  = GP0 (UART0 TX)     Pin 2  = GP1 (UART0 RX)
  Pin 3  = GND                Pin 4  = GP2
  ...
```

GP0 and GP1 are the first two GPIO pins, right next to the first GND pin.  This makes wiring straightforward.

## Part 5: Flashing the Firmware

### Method 1: UF2 via USB (BOOTSEL mode)

1. Hold the BOOTSEL button on the Pico 2
2. While holding, connect USB to computer
3. Release BOOTSEL — the Pico appears as a USB drive named "RP2350"
4. Copy `uart.uf2` to the USB drive
5. The Pico flashes automatically and reboots

### Method 2: picotool

```
  picotool load uart.uf2 -f
```

This requires the Pico to be in BOOTSEL mode or have a debug probe connected.

### Method 3: OpenOCD with Debug Probe

```
  openocd -f interface/cmsis-dap.cfg -f target/rp2350.cfg \
          -c "adapter speed 5000" \
          -c "program uart.elf verify reset exit"
```

This uses a CMSIS-DAP debug probe (like the Raspberry Pi Debug Probe) connected to the SWD pins.  It flashes the ELF directly, verifies the contents, resets the chip, and exits.

## Part 6: Testing with a Terminal

### Terminal Setup

Open a serial terminal program:
- **Windows**: PuTTY, TeraTerm, or Windows Terminal with `mode COM`
- **macOS/Linux**: `screen /dev/ttyUSB0 115200`, or `minicom`, or `picocom`

Configure:
```
  Port:      COMx (Windows) or /dev/ttyUSBx (Linux)
  Baud rate: 115200
  Data bits: 8
  Parity:    None
  Stop bits: 1
  Flow ctrl: None
```

### Expected Behavior

1. Open the terminal at 115200 8N1
2. Type a character (e.g., 'A')
3. The character appears on screen — echoed by the Pico

Every character you type is:
1. Sent from your terminal to the USB-serial adapter
2. Serialized and transmitted to GP1 (RX) on the Pico
3. Received by `UART0_In` (read from RX FIFO)
4. Immediately sent back by `UART0_Out` (written to TX FIFO)
5. Serialized and transmitted from GP0 (TX) to the USB-serial adapter
6. Received by the adapter and sent to your terminal
7. Displayed on screen

If local echo is enabled in your terminal, you will see each character twice (once from local echo, once from the firmware echo).  Disable local echo to see single characters.

## Part 7: The Complete Boot Flow

Let us trace the entire execution from power-on to the first echoed character:

```
  ┌─────────────────────────────────────────────────────────┐
  │ 1. POWER ON                                             │
  │    Internal boot ROM begins executing                   │
  │    Ring oscillator provides ~6.5 MHz initial clock      │
  └─────────────────────────┬───────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────┐
  │ 2. BOOT ROM SCANS FLASH                                 │
  │    Reads 0x10000000, finds marker 0xFFFFDED3            │
  │    Parses IMAGE_DEF: RISC-V, RP2350, EXE                │
  │    Reads entry point: Reset_Handler                     │
  │    Reads stack top: 0x20082000                          │
  └─────────────────────────┬───────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────┐
  │ 3. JUMP TO FIRMWARE                                     │
  │    PC = Reset_Handler address                           │
  └─────────────────────────┬───────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────┐
  │ 4. INIT SEQUENCE (reset_handler.s)                      │
  │    Init_Stack → sp = 0x20082000                         │
  │    Init_Trap_Vector → mtvec = Default_Trap_Handler      │
  │    Init_XOSC → 12 MHz crystal stable                    │
  │    Enable_XOSC_Peri_Clock → clk_peri = XOSC             │
  │    Init_Subsystem → IO_BANK0 released from reset        │
  │    UART_Release_Reset → UART0 released from reset       │
  │    UART_Init → GP0=TX, GP1=RX, 115200 8N1, FIFOs on     │
  │    Enable_Coprocessor → (no-op)                         │
  └─────────────────────────┬───────────────────────────────┘
                            │
  ┌─────────────────────────▼───────────────────────────────┐
  │ 5. APPLICATION (main.s)                                 │
  │    .Loop:                                               │
  │      UART0_In → poll RXFE, read byte into a0            │
  │      UART0_Out → poll TXFF, write a0 to TX FIFO         │
  │      j .Loop                                            │
  └─────────────────────────────────────────────────────────┘
```

## Part 8: Debugging Tips

### Nothing Happens After Flashing

1. **Check wiring**: TX→RX, RX→TX, GND→GND
2. **Check baud rate**: must be 115200 on both sides
3. **Check COM port**: use Device Manager (Windows) or `ls /dev/ttyUSB*` (Linux) to find the correct port
4. **Check voltage**: must be 3.3 V logic levels

### Garbled Characters

1. **Baud rate mismatch**: most common cause.  Verify both sides use 115200.
2. **Clock issue**: if XOSC initialization fails, the UART runs on the imprecise ring oscillator.  Check crystal connections on the board.
3. **Data format mismatch**: ensure both sides use 8N1.

### No Response (Characters Sent but Not Echoed)

1. **TX/RX swapped**: the most common wiring mistake.  Swap the TX and RX wires.
2. **UART not initialized**: if the boot metadata is wrong, the firmware may not start.  Verify the UF2 file was accepted (the USB drive should disappear after copying).
3. **Wrong GPIO pins**: verify you are connected to GP0 and GP1 (pins 1 and 2), not other pins.

### Double Characters

Local echo is enabled in your terminal.  Disable it:
- PuTTY: Terminal → Local echo → Force off
- minicom: Ctrl-A E to toggle echo

## Part 9: What You Have Learned

Looking back across all 30 chapters:

**Foundations (Chapters 1–6):**
- How computers work: CPU, memory, bus
- Number systems: binary, hex, decimal
- Memory addressing, endianness, word alignment
- Registers and the load-store architecture
- The fetch-decode-execute cycle

**RISC-V Instructions (Chapters 7–12):**
- The ISA overview and encoding formats
- Immediate and upper-immediate instructions
- Arithmetic and logic operations
- Load and store instructions
- Branch instructions
- Jump, call, and return

**Assembly Programming (Chapters 13–18):**
- Pseudoinstructions
- Assembler directives
- The calling convention and stack frames
- Bitwise operations for hardware
- Memory-mapped I/O
- RP2350 architecture

**Build System (Chapters 19–20):**
- The linker script: sections, memory regions, symbols
- The build pipeline: assemble, link, objcopy, UF2

**Source Code (Chapters 21–29):**
- Boot metadata (image_def.s)
- Constants (constants.s)
- Stack and vector table (stack.s, vector_table.s)
- Reset handler and trap vector (reset_handler.s)
- Crystal oscillator (xosc.s)
- Reset controller (reset.s)
- UART driver: init, transmit, receive (uart.s)
- Application entry point (main.s)

**Integration (Chapter 30 — this chapter):**
- Build, flash, wire, test, debug

## Part 10: Where to Go Next

With this foundation, you can:

1. **Add string output**: write a function that loops through a null-terminated string in `.rodata` and calls `UART0_Out` for each byte

2. **Add GPIO LED control**: use the SIO peripheral to toggle GPIO25 (onboard LED) — fill in the `gpio.s` stubs

3. **Add interrupts**: configure `mie`/`mstatus` CSRs to trigger on UART RX instead of polling

4. **Add a command parser**: read characters into a buffer, compare against command strings, execute actions

5. **Add SPI or I2C drivers**: follow the same pattern (release from reset, configure pins, set parameters, enable)

6. **Explore the RP2350 data sheet**: every peripheral follows the same register-based interface pattern you now understand

The skills you have built — reading data sheets, understanding registers, writing memory-mapped I/O code in assembly, building bare-metal firmware — are transferable to any microcontroller, any architecture, and any embedded system.

## Practice Problems

1. What is the first byte in flash after a successful build?
2. What UF2 family ID identifies RP2350?
3. What three wires connect the Pico to a USB-serial adapter?
4. What terminal settings are needed for this firmware?
5. What is the total firmware size approximately?

### Answers

1. 0xD3 (least significant byte of the start marker 0xFFFFDED3, stored little-endian).
2. 0xE48BFF5A
3. GP0→RX (TX data), GP1←TX (RX data), GND→GND (common ground).
4. 115200 baud, 8 data bits, no parity, 1 stop bit (8N1), no flow control.
5. Approximately 500–800 bytes of machine code in flash.

## Chapter Summary

This chapter integrated all previous knowledge into a complete workflow: build the 11 source files through a 4-stage pipeline (assemble, link, extract, convert), flash the resulting UF2 to the Pico 2, wire GP0 (TX) and GP1 (RX) to a USB-serial adapter with crossed connections, open a terminal at 115200 8N1, and verify character echo.  The firmware boots through a precise initialization sequence, enters an infinite loop, and echoes every received byte — a complete bare-metal RISC-V system built from scratch and understood down to every single bit.
