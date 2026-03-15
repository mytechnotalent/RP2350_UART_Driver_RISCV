# Chapter 22: constants.s — Every Definition Explained

## Introduction

The `constants.s` file defines every memory address and constant used by the firmware.  It contains no instructions and generates no machine code.  Every `.equ` is a compile-time symbol substitution.  This chapter explains what each constant represents and why it has its specific value.

## Full Source: constants.s

```asm
.equ STACK_TOP,                   0x20082000
.equ STACK_LIMIT,                 0x2007a000
.equ VECTOR_TABLE_BASE,           0x20000000
.equ XOSC_BASE,                   0x40048000
.equ XOSC_CTRL,                   XOSC_BASE + 0x00
.equ XOSC_STATUS,                 XOSC_BASE + 0x04
.equ XOSC_STARTUP,                XOSC_BASE + 0x0c
.equ PPB_BASE,                    0xe0000000
.equ MSTATUS_MIE,                 (1<<3)
.equ MTVEC_MODE_DIRECT,           0
.equ CLOCKS_BASE,                 0x40010000
.equ CLK_PERI_CTRL,               CLOCKS_BASE + 0x48
.equ RESETS_BASE,                 0x40020000
.equ RESETS_RESET,                RESETS_BASE + 0x0
.equ RESETS_RESET_CLEAR,          RESETS_BASE + 0x3000
.equ RESETS_RESET_DONE,           RESETS_BASE + 0x8
.equ IO_BANK0_BASE,               0x40028000
.equ IO_BANK0_GPIO16_CTRL_OFFSET, 0x84
.equ PADS_BANK0_BASE,             0x40038000
.equ PADS_BANK0_GPIO16_OFFSET,    0x44
.equ UART0_BASE,                  0x40070000
```

## Stack Constants

### STACK_TOP = 0x20082000

```asm
.equ STACK_TOP,                   0x20082000
```

This is the initial stack pointer value.  SRAM starts at 0x20000000 and extends 520 KB to 0x20082000.  The stack pointer is set to the very top of available SRAM.

Why 0x20082000?  520 KB = 520 × 1024 = 532,480 bytes = 0x82000 bytes.  SRAM base + 0x82000 = 0x20082000.

Since the stack grows downward (toward lower addresses), `sp` starts at the highest address and decreases as data is pushed.

### STACK_LIMIT = 0x2007A000

```asm
.equ STACK_LIMIT,                 0x2007a000
```

A safety boundary.  If `sp` decreases below this address, the stack has overflowed into other SRAM data.

0x20082000 - 0x2007A000 = 0x8000 = 32,768 bytes = 32 KB of stack space.

Our firmware uses very little stack (no deep call chains, no local arrays), so 32 KB is vastly more than needed.

### VECTOR_TABLE_BASE = 0x20000000

```asm
.equ VECTOR_TABLE_BASE,           0x20000000
```

The start of SRAM.  This constant is defined but not used in our firmware (the vector table is in flash, not RAM).  It exists for potential future use if the vector table needed to be relocated to RAM.

## Crystal Oscillator Constants

### XOSC_BASE = 0x40048000

```asm
.equ XOSC_BASE,                   0x40048000
```

Base address of the XOSC peripheral block.  This value comes directly from the RP2350 data sheet, section on XOSC registers.

### XOSC Register Offsets

```asm
.equ XOSC_CTRL,                   XOSC_BASE + 0x00 # = 0x40048000
.equ XOSC_STATUS,                 XOSC_BASE + 0x04 # = 0x40048004
.equ XOSC_STARTUP,                XOSC_BASE + 0x0c # = 0x4004800C
```

Each register address is computed as base + offset:

| Constant | Offset | Address | Purpose |
|---|---:|---:|---|
| XOSC_CTRL | 0x00 | 0x40048000 | Enable and frequency range |
| XOSC_STATUS | 0x04 | 0x40048004 | Stable/running status |
| XOSC_STARTUP | 0x0C | 0x4004800C | Startup delay counter |

Note: our code loads each full address with `li` rather than using base+offset `lw`.  This is a stylistic choice — it works because each register access is independent.

## System Constants

### PPB_BASE = 0xE0000000

```asm
.equ PPB_BASE,                    0xe0000000
```

Private Peripheral Bus base.  Used for system-level registers on ARM cores.  On RISC-V, most system configuration uses CSRs instead.  This constant is defined for completeness but not used.

### MSTATUS_MIE = (1 << 3)

```asm
.equ MSTATUS_MIE,                 (1<<3)
```

Bit 3 of the `mstatus` CSR is the Machine Interrupt Enable bit.  When set, interrupts are globally enabled.  Our firmware does not enable interrupts (we use polling), but this constant is defined for potential use.

Value: `(1 << 3)` = 0x00000008 = binary `0000...1000`.

### MTVEC_MODE_DIRECT = 0

```asm
.equ MTVEC_MODE_DIRECT,           0
```

The lower 2 bits of the `mtvec` CSR specify the vector mode:
- 0 = Direct: all traps jump to the same handler address
- 1 = Vectored: different traps jump to different addresses based on cause

Our firmware uses direct mode (all traps go to `Default_Trap_Handler`).

## Clock Constants

### CLOCKS_BASE = 0x40010000

```asm
.equ CLOCKS_BASE,                 0x40010000
```

Base address of the clock controller peripheral.

### CLK_PERI_CTRL = CLOCKS_BASE + 0x48

```asm
.equ CLK_PERI_CTRL,               CLOCKS_BASE + 0x48 # = 0x40010048
```

The peripheral clock control register.  Bit 11 enables the clock; bits [7:5] select the clock source (AUXSRC).

## Reset Controller Constants

### RESETS_BASE = 0x40020000

```asm
.equ RESETS_BASE,                 0x40020000
```

Base address of the reset controller.

### Reset Register Addresses

```asm
.equ RESETS_RESET,                RESETS_BASE + 0x0 # = 0x40020000
.equ RESETS_RESET_CLEAR,          RESETS_BASE + 0x3000 # = 0x40023000
.equ RESETS_RESET_DONE,           RESETS_BASE + 0x8 # = 0x40020008
```

| Constant | Address | Purpose |
|---|---:|---|
| RESETS_RESET | 0x40020000 | Main reset control register |
| RESETS_RESET_CLEAR | 0x40023000 | Atomic clear alias (write-1-to-clear) |
| RESETS_RESET_DONE | 0x40020008 | Reset done status |

**RESETS_RESET_CLEAR** is interesting: RP2350 provides atomic register access aliases.  Writing to the `_CLEAR` alias (base + 0x3000) atomically clears the written bits without a read-modify-write.  Our firmware uses explicit RMW instead, but the atomic alias exists as an alternative.

## GPIO Constants

### IO_BANK0_BASE = 0x40028000

```asm
.equ IO_BANK0_BASE,               0x40028000
```

Base address of the I/O bank 0 (GPIO function control).

### IO_BANK0_GPIO16_CTRL_OFFSET = 0x84

```asm
.equ IO_BANK0_GPIO16_CTRL_OFFSET, 0x84
```

Offset for GPIO16 control register.  Defined for potential use (LED on Pico 2 board).  Our UART firmware uses GPIO0/1 with hardcoded offsets 0x04 and 0x0C.

### PADS_BANK0_BASE = 0x40038000

```asm
.equ PADS_BANK0_BASE,             0x40038000
```

Base address of the pad control peripheral (electrical characteristics).

### PADS_BANK0_GPIO16_OFFSET = 0x44

```asm
.equ PADS_BANK0_GPIO16_OFFSET,    0x44
```

Pad register offset for GPIO16.  Defined for potential LED use.

## UART Constants

### UART0_BASE = 0x40070000

```asm
.equ UART0_BASE,                  0x40070000
```

Base address of the UART0 peripheral.  All UART register offsets are hardcoded in `uart.s` (0x00, 0x04, 0x08, 0x18, 0x24, 0x28, 0x2C, 0x30).

## How Constants Are Used

When any source file includes `constants.s`:

```asm
.include "constants.s"
```

All `.equ` definitions become available.  Then:

```asm
  li    t0, UART0_BASE                           # assembler substitutes 0x40070000
```

The assembler replaces `UART0_BASE` with `0x40070000` and generates the appropriate `lui`+`addi` sequence.

No code or data is emitted by `constants.s` itself.  It produces zero bytes in the final binary.

## Practice Problems

1. What is the computed address of XOSC_STARTUP?
2. How many bytes of stack space does STACK_TOP - STACK_LIMIT give?
3. What is MSTATUS_MIE in hexadecimal?
4. Does `constants.s` generate any machine code?
5. What is the atomic clear alias address for the reset controller?

### Answers

1. 0x40048000 + 0x0C = 0x4004800C
2. 0x20082000 - 0x2007A000 = 0x8000 = 32,768 bytes = 32 KB
3. (1 << 3) = 0x00000008
4. No.  `.equ` directives are pure text substitutions at assembly time.
5. 0x40020000 + 0x3000 = 0x40023000 (RESETS_RESET_CLEAR)

## Chapter Summary

`constants.s` defines all memory addresses and constants as `.equ` directives: stack boundaries, XOSC registers, clock control, reset controller, GPIO banks, and UART0 base.  Each address comes from the RP2350 data sheet.  These definitions generate no machine code — they are compile-time substitutions used by `li` and other instructions throughout the firmware.
