# Chapter 18: The RP2350 Microcontroller — Architecture and Hardware

## Introduction

This chapter describes the RP2350 chip itself: its processor cores, memory subsystem, peripheral interconnect, reset and clock infrastructure, and boot process.  Understanding the hardware is essential before walking through the firmware that configures it.

## RP2350 Block Diagram

```
                         RP2350
                         ======

   +--------------+    +--------------+
   |     ARM      |    |   RISC-V     |   dual architecture
   |  Cortex-M33  |    |   Hazard3    |   (choose at boot)
   |    Core 0    |    |    Core 0    |
   +------+-------+    +------+-------+
          |                   |
          +--------+----------+
                   |
          +--------+---------+
          |   Bus Fabric     |
          | (AHB-Lite xbar)  |
          +--+-----+------+--+
             |     |      |
        +----+  +--+--+  +--+---+
        |       |     |  |      |
   +----+---+   +--+--+  +---+--+---+
   |  SRAM  |   |Flash|  |   APB    |
   |  520K  |   | XIP |  |  Bridge  |
   +--------+   +-----+  +----+-----+
                              |
              +---------------+---------------+
              |       APB Peripherals         |
              |  UART  SPI  I2C  GPIO  PWM    |
              |  Timers  ADC  Clocks  Resets  |
              +-------------------------------+
```

## The Hazard3 RISC-V Core

Hazard3 is a custom RV32IMAC core designed by Raspberry Pi.  Key characteristics:

| Feature | Detail |
|---|---|
| ISA | rv32imac_zicsr |
| Pipeline | 3-stage (fetch, decode/execute, writeback) |
| Privilege levels | Machine mode (M-mode) only in our firmware |
| Hardware multiply | Single-cycle 32×32 multiply |
| Compressed instructions | 16-bit C extension support |
| Branch prediction | Static (backward taken, forward not taken) |

The Hazard3 core runs at whatever clock frequency is configured.  After reset, the chip runs from an internal ring oscillator (~6.5 MHz).  Our firmware switches to the 12 MHz crystal oscillator.

## Memory System

### Flash via XIP

The RP2350 has no internal flash.  An external QSPI flash chip is connected.  The XIP (Execute In Place) controller maps flash contents to the address range 0x10000000-0x11FFFFFF.

When the CPU fetches an instruction from 0x10000xxx, the XIP controller reads the corresponding data from the external flash chip and returns it.  To the CPU, this looks like regular memory.

Our firmware code lives entirely in this XIP-mapped flash.

### SRAM

520 KB of on-chip SRAM at address 0x20000000.  This is used for:
- Stack (our firmware sets sp to 0x20082000, the top of SRAM)
- Data variables (we have none in this minimal firmware)
- Heap (not used)

SRAM is zero-wait-state for the core, making it fast for stack operations.

## Reset Infrastructure

On RP2350, most peripherals start in a reset state after power-on.  A peripheral held in reset has its clock gated and its logic held in a known state.

The **RESETS** block (base 0x40020000) controls which peripherals are in reset:

```
  RESETS_RESET register (offset 0x00):
    Bit 31: USBCTRL
    ...
    Bit 26: UART0        ← we clear this to enable UART0
    ...
    Bit 6:  IO_BANK0     ← we clear this to enable GPIO
    ...
    Bit 0:  ADC
```

**Bit = 1**: peripheral is held in reset (disabled)
**Bit = 0**: peripheral is released from reset (enabled)

After clearing a reset bit, you must poll RESETS_RESET_DONE to confirm the peripheral has completed its reset exit sequence:

```
  RESETS_RESET_DONE register (offset 0x08):
    Same bit assignments as RESETS_RESET
    Bit = 1: peripheral has completed reset exit
    Bit = 0: peripheral is still resetting
```

## Clock Infrastructure

RP2350 has a sophisticated clock system:

### Clock Sources
1. **ROSC** (Ring Oscillator): internal, ~6.5 MHz, imprecise but always available
2. **XOSC** (Crystal Oscillator): external 12 MHz crystal, precise, must be started
3. **PLLs**: multiply XOSC frequency for higher system clocks (up to 150 MHz)

### Clock Generators

The CLOCKS block (base 0x40010000) routes clock sources to different parts of the chip:

| Clock | Purpose | Our Configuration |
|---|---|---|
| clk_sys | CPU core clock | Defaults to ROSC after reset |
| clk_peri | Peripheral clock | We enable this from XOSC |
| clk_ref | Reference clock | Used internally |
| clk_usb | USB clock | Not used |
| clk_adc | ADC clock | Not used |

Our firmware does NOT configure PLLs or change clk_sys.  We:
1. Start the crystal oscillator (XOSC)
2. Route XOSC to the peripheral clock (clk_peri)
3. Leave the system clock on ROSC

This means our CPU runs at ~6.5 MHz (ROSC) but UART uses the 12 MHz crystal for precise baud rate timing.

## GPIO System

RP2350 has 30 GPIO pins.  Each pin has three layers of configuration:

### 1. IO Bank (IO_BANK0, base 0x40028000)

Controls the pin function (FUNCSEL).  Each GPIO has a control register:

| Offset | Register | Controls |
|---:|---|---|
| 0x04 | GPIO0_CTRL | Function select for GPIO0 |
| 0x0C | GPIO1_CTRL | Function select for GPIO1 |
| 0x14 | GPIO2_CTRL | Function select for GPIO2 |
| ... | ... | ... |

The FUNCSEL field (bits [4:0]) selects what the pin does:
- 0: SIO (software I/O)
- 1: SPI
- 2: UART
- 3: I2C
- 5: PIO0
- 31: NULL (disconnect)

### 2. Pads Bank (PADS_BANK0, base 0x40038000)

Controls the electrical characteristics:

| Bit | Name | Description |
|---:|---|---|
| 7 | OD | Output disable |
| 6 | IE | Input enable |
| 5:4 | DRIVE | Drive strength (0=2mA, 1=4mA, 2=8mA, 3=12mA) |
| 3 | PUE | Pull-up enable |
| 2 | PDE | Pull-down enable |
| 1 | SCHMITT | Schmitt trigger enable |
| 0 | SLEWFAST | Slew rate (0=slow, 1=fast) |

### 3. SIO (Single-cycle IO)

For direct GPIO control (set/clear/toggle output, read input).  Not used for UART because UART controls the pins through its function select.

## UART Hardware

The RP2350 UART is a PrimeCell PL011 UART (ARM IP block).  Even though we run on RISC-V, the peripheral hardware is the same.

Key features:
- 16-byte TX and RX FIFOs
- Programmable baud rate (integer + fractional divisors)
- Configurable word length, parity, and stop bits
- Hardware flow control (CTS/RTS)
- Interrupt support

The baud rate is derived from the peripheral clock:

```
  Baud Rate Divisor = clk_peri / (16 × desired_baud_rate)
                    = 12,000,000 / (16 × 115,200)
                    = 12,000,000 / 1,843,200
                    = 6.5104...

  IBRD = 6         (integer part)
  FBRD = round(0.5104 × 64) = round(32.67) = 33  (fractional part)
```

## Boot Sequence (High Level)

1. Power on → boot ROM runs
2. Boot ROM reads IMAGE_DEF from start of flash
3. IMAGE_DEF specifies: RISC-V architecture, entry point = Reset_Handler
4. Boot ROM sets PC to Reset_Handler address
5. Our firmware takes over

Chapter 20 covers IMAGE_DEF in exhaustive detail.

## What Our Firmware Must Do

Given this hardware, our firmware initialization sequence must:

1. **Set up the stack** — CPU needs a stack for function calls
2. **Set up the trap vector** — CPU needs to know where to go on exceptions
3. **Start the crystal oscillator** — for precise UART timing
4. **Enable the peripheral clock** — so UART has a clock source
5. **Release IO_BANK0 from reset** — so we can configure GPIO pins
6. **Release UART0 from reset** — so we can access UART registers
7. **Configure GPIO pins** — assign FUNCSEL=2 (UART) to GPIO0 and GPIO1
8. **Configure GPIO pads** — enable output on TX, input on RX
9. **Program UART registers** — baud rate, word format, enable TX/RX

Each of these steps maps directly to a function in our firmware, which we will walk through in the remaining chapters.

## Practice Problems

1. What clock source does UART use for baud rate timing?
2. What does clearing bit 26 in RESETS_RESET do?
3. What is the FUNCSEL value for UART on GPIO0?
4. How many bytes are in the UART TX FIFO?
5. What happens if you access UART registers before releasing UART from reset?

### Answers

1. The peripheral clock (clk_peri), which we configure to use the 12 MHz crystal oscillator.
2. Releases UART0 from reset, allowing its registers to be accessed.
3. 2 (UART function)
4. 16 bytes
5. Undefined behavior — the peripheral is in reset, its registers are not functional.

## Chapter Summary

RP2350 has Hazard3 RISC-V cores, 520 KB SRAM, external flash via XIP, and APB peripherals.  Peripherals start in reset and must be explicitly released.  Clocks must be configured before peripherals work.  GPIO pins have function selects and pad configurations.  UART uses PL011 hardware with FIFOs and programmable baud rate.  Our firmware initializes all of this from scratch.
