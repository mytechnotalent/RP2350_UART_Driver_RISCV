# Chapter 3: Memory — Addresses, Bytes, Words, and Endianness

## Introduction

Memory is a linear array of bytes.  Every byte has a unique numerical address.  The CPU uses these addresses to read instructions, read data, and write data.  Understanding memory addressing is critical because in bare-metal programming, you manually read and write specific addresses to control hardware.

## The Byte-Addressable Model

Memory is organized as a sequence of bytes, each with an address:

```
  Address    Content
  0x00000000  [byte 0]
  0x00000001  [byte 1]
  0x00000002  [byte 2]
  0x00000003  [byte 3]
  0x00000004  [byte 4]
  ...
```

On a 32-bit machine, addresses are 32 bits wide, meaning the theoretical address space is 2³² = 4,294,967,296 bytes (4 GB).

## Words and Alignment

A word on RV32 is 32 bits = 4 bytes.  When the CPU executes `lw` (load word), it reads 4 consecutive bytes from memory.

**Alignment** means the starting address of a multi-byte access should be divisible by its size:

| Access Type | Size | Must Be Aligned To |
|---|---:|---:|
| Byte (lb/sb) | 1 byte | Any address |
| Halfword (lh/sh) | 2 bytes | Address divisible by 2 |
| Word (lw/sw) | 4 bytes | Address divisible by 4 |

Misaligned access can cause hardware exceptions on some RISC-V implementations.  Always keep word accesses 4-byte aligned.

Example of aligned addresses:
```
  0x20000000  ← aligned to 4 (divisible by 4)
  0x20000004  ← aligned to 4
  0x20000008  ← aligned to 4
  0x2000000C  ← aligned to 4
  0x20000003  ← NOT aligned to 4 (would cause fault on lw)
```

## Endianness

When you store a 32-bit value across 4 bytes, which byte goes where?

### Little-Endian (Used by RP2350 RISC-V)

The least significant byte (LSB) is stored at the lowest address:

```
  Value: 0x12345678
  Stored at address 0x20000000:

  Address      Byte
  0x20000000   0x78  (least significant byte)
  0x20000001   0x56
  0x20000002   0x34
  0x20000003   0x12  (most significant byte)
```

This matters when you inspect raw memory dumps or when you construct multi-byte values from individual bytes in IMAGE_DEF structures (as we will see in chapter 23).

## Memory Regions on RP2350

The RP2350 address space is divided into regions.  Not all addresses correspond to physical memory.  Some map to flash, some to SRAM, and some to peripheral control registers.

```
  0x00000000 - 0x0FFFFFFF  Boot ROM and system regions
  0x10000000 - 0x11FFFFFF  Flash / XIP (Execute In Place)  — 32 MB window
  0x20000000 - 0x2007FFFF  SRAM (520 KB total)
  0x40000000 - 0x4FFFFFFF  Peripheral registers (APB/AHB)
  0xE0000000 - 0xEFFFFFFF  Private peripheral bus (PPB)
```

In our firmware:
- **Code** lives in flash starting at `0x10000000`
- **Stack** lives in SRAM near the top: `0x20082000`
- **Peripheral registers** are scattered through the `0x40000000` range

## Memory-Mapped I/O

This is the most important concept for bare-metal programming.

On RP2350, peripheral hardware blocks are controlled by reading and writing specific addresses.  From the CPU's perspective, there is no difference between accessing RAM and accessing a peripheral register.  Both use the same `lw` and `sw` instructions.

For example, the UART0 data register is at address `0x40070000`.  When you execute:

```asm
  li    t0, 0x40070000                           # load UART0 base address
  sw    a0, 0x00(t0)                             # write byte to UART data register
```

The CPU places `0x40070000` on the address bus and the data from `a0` on the data bus.  The UART hardware sees this write and transmits the byte on the serial line.  You did not call a function.  You did not use a driver API.  You wrote to a memory address, and the hardware responded.

## Address Arithmetic

Peripheral registers are typically organized as:
- **Base address**: the starting address of the peripheral block
- **Offset**: the distance from base to a specific register within the block

```
  Register address = Base + Offset
```

For UART0:
- Base: `0x40070000` (UART0_BASE)
- UARTDR offset: `0x00`, so UARTDR address = `0x40070000`
- UARTFR offset: `0x18`, so UARTFR address = `0x40070018`
- UARTIBRD offset: `0x24`, so UARTIBRD address = `0x40070024`

In assembly, we load the base into a register and use the offset in the instruction:

```asm
  li    t0, UART0_BASE                           # t0 = 0x40070000
  lw    t1, 0x18(t0)                             # t1 = memory[0x40070018] = UARTFR
```

The offset `0x18` is encoded directly in the `lw` instruction.  No extra addition instruction is needed.

## RP2350 Peripheral Base Addresses (From Our Project)

| Symbol | Address | Peripheral |
|---|---:|---|
| XOSC_BASE | 0x40048000 | Crystal oscillator |
| CLOCKS_BASE | 0x40010000 | Clock control |
| RESETS_BASE | 0x40020000 | Reset controller |
| IO_BANK0_BASE | 0x40028000 | GPIO function control |
| PADS_BANK0_BASE | 0x40038000 | GPIO pad electrical config |
| UART0_BASE | 0x40070000 | UART0 serial port |

These are defined in `constants.s` and used throughout the firmware.

## Practice Problems

1. If a word is stored at address `0x20000004`, what are the addresses of its 4 bytes?
2. In little-endian, if value `0xFFFFDED3` is at address `0x10000000`, what byte is at `0x10000002`?
3. What is the address of the UART0 flag register (UARTFR), given base = `0x40070000` and offset = `0x18`?

### Answers

1. `0x20000004`, `0x20000005`, `0x20000006`, `0x20000007`
2. `0xDE` (third byte from LSB: D3, DE, FF, FF)
3. `0x40070000 + 0x18 = 0x40070018`

## Chapter Summary

Memory is an array of bytes with addresses.  Words are 4 bytes on RV32 and should be 4-byte aligned.  RP2350 uses little-endian byte order.  Peripheral registers are controlled through memory-mapped I/O at specific addresses.  Register address = base + offset.
