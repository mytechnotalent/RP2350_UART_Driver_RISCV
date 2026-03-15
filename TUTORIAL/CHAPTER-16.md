# Chapter 16: Bitwise Operations for Hardware Programming

## Introduction

Peripheral registers are packed with individual bits and bit fields, each controlling a different aspect of hardware behavior.  This chapter teaches the bit manipulation patterns used throughout our firmware to read, set, clear, and test individual bits within 32-bit registers.

## Bit Numbering

Bits are numbered 0 (least significant) to 31 (most significant):

```
  Bit:  31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
```

Bit N has the value 2ⁿ.  The expression `(1 << N)` creates a mask with only bit N set:

```
  (1 << 0)  = 0x00000001 = bit 0
  (1 << 5)  = 0x00000020 = bit 5
  (1 << 6)  = 0x00000040 = bit 6
  (1 << 11) = 0x00000800 = bit 11
  (1 << 26) = 0x04000000 = bit 26
  (1 << 31) = 0x80000000 = bit 31
```

## The Four Fundamental Bit Operations

### 1. Test a Bit (Is it set?)

Use AND with a mask:

```asm
  andi  t1, t1, (1 << 5)                         # isolate bit 5
  bnez  t1, label                                # branch if bit 5 was set
```

**How it works**: AND preserves bits where the mask is 1 and clears bits where the mask is 0.  After AND with `(1 << 5)`, only bit 5 remains.  If it was set, the result is non-zero.

From `uart.s` — testing TX FIFO full:
```asm
  andi  t1, t1, UART_TXFF                        # UART_TXFF = (1 << 5) = 0x20
  bnez  t1, .Lwait_tx                            # if bit 5 set, FIFO is full
```

### 2. Set a Bit (Force it to 1)

Use OR with a mask:

```asm
  ori   t1, t1, (1 << 11)                        # set bit 11
```

**How it works**: OR sets bits where the mask is 1 and leaves other bits unchanged.

From `xosc.s` — setting the enable bit in CLK_PERI_CTRL:
```asm
  ori   t1, t1, (1 << 11)                        # set bit 11 (CLK_PERI enable)
```

### 3. Clear a Bit (Force it to 0)

Use AND with the inverted mask:

```asm
  li    t2, (1 << 6)                             # bit mask
  not   t2, t2                                   # invert: 0xFFFFFFBF
  and   t1, t1, t2                               # clear bit 6, preserve all others
```

**How it works**: NOT flips the mask so the target bit is 0 and all others are 1.  AND then clears only the target bit.

From `reset.s` — clearing reset bit for IO_BANK0:
```asm
  li    t2, (1 << 6)                             # IO_BANK0 reset bit
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear bit 6 in RESETS_RESET
  sw    t1, RESETS_RESET(t0)                     # write back
```

### 4. Toggle a Bit (Flip it)

Use XOR with a mask:

```asm
  xori  t1, t1, (1 << 3)                         # toggle bit 3
```

**How it works**: XOR flips bits where the mask is 1 and leaves others unchanged.

Our firmware does not toggle bits, but this is common in LED control and flag manipulation.

## The Read-Modify-Write Pattern

Most peripheral registers cannot be written bit by bit.  You must:
1. **Read** the entire 32-bit register
2. **Modify** the bits you want to change
3. **Write** the entire 32-bit value back

This is the most important pattern in embedded programming:

```asm
  li    t0, PERIPHERAL_BASE                      # load base address
  lw    t1, REGISTER_OFFSET(t0)                  # READ current value
  # ... modify t1 using AND/OR/XOR ...           # MODIFY specific bits
  sw    t1, REGISTER_OFFSET(t0)                  # WRITE modified value back
```

### Example: Clearing Reset for IO_BANK0 (reset.s)

```asm
  li    t0, RESETS_BASE                          # t0 = 0x40020000
  lw    t1, RESETS_RESET(t0)                     # READ: t1 = current reset state
  li    t2, (1 << 6)                             # t2 = 0x00000040 (IO_BANK0 bit)
  not   t2, t2                                   # t2 = 0xFFFFFFBF (inverted mask)
  and   t1, t1, t2                               # MODIFY: clear bit 6
  sw    t1, RESETS_RESET(t0)                     # WRITE: release IO_BANK0 from reset
```

### Example: Enabling Peripheral Clock (xosc.s)

```asm
  li    t0, CLOCKS_BASE                          # t0 = 0x40010000
  lw    t1, CLK_PERI_CTRL(t0)                    # READ: current clock control
  ori   t1, t1, (1 << 11)                        # MODIFY: set enable bit 11
  sw    t1, CLK_PERI_CTRL(t0)                    # WRITE: enable peripheral clock
```

## Multi-Bit Fields

Some register fields span multiple bits.  For example, GPIO FUNCSEL is bits [4:0] (5 bits, 32 possible functions).

### Reading a Multi-Bit Field

```asm
  lw    t1, GPIO_CTRL(t0)                        # read GPIO control register
  andi  t1, t1, 0x1F                             # mask bits [4:0] (FUNCSEL)
```

### Writing a Multi-Bit Field

To set FUNCSEL to 2 (UART function):
```asm
  li    t1, 2                                    # FUNCSEL = 2 for UART
  sw    t1, GPIO0_CTRL(t0)                       # write control register
```

If other bits in the register matter, you need read-modify-write:
```asm
  lw    t1, GPIO0_CTRL(t0)                       # read current value
  andi  t1, t1, ~0x1F                            # clear bits [4:0]
  ori   t1, t1, 2                                # set FUNCSEL = 2
  sw    t1, GPIO0_CTRL(t0)                       # write back
```

In our firmware, we write the entire register because FUNCSEL is the only field we care about, and other fields default to 0.

## Bit Testing: The BGEZ Trick

The `bgez` (branch if greater than or equal to zero) instruction does a signed comparison.  In two's complement, a 32-bit number is negative if and only if bit 31 is set.

```asm
  lw    t1, XOSC_STATUS(t0)                      # read XOSC status
  bgez  t1, .Lwait_xosc                          # loop if bit 31 clear
```

This tests bit 31 without any AND masking.  It works because:
- If bit 31 = 0: value ≥ 0 (signed) → branch taken (keep waiting)
- If bit 31 = 1: value < 0 (signed) → fall through (XOSC stable)

This is faster than `andi + bnez` because it saves one instruction.

## Constants in Our Firmware

All bit positions are defined as `.equ` constants in `constants.s`:

```asm
  .equ UART_TXFF, (1 << 5)                       # TX FIFO full flag
  .equ UART_RXFE, (1 << 4)                       # RX FIFO empty flag
  .equ MSTATUS_MIE, (1 << 3)                     # machine interrupt enable
  .equ RESETS_IO_BANK0, (1 << 6)                 # IO_BANK0 reset bit
  .equ RESETS_UART0, (1 << 26)                   # UART0 reset bit
```

Using named constants instead of magic numbers makes the code self-documenting.

## Common Bit Patterns Summary

| Operation | Instructions | Purpose |
|---|---|---|
| Test bit N | `andi t1, t1, (1<<N); bnez` | Check if bit is set |
| Set bit N | `ori t1, t1, (1<<N)` | Force bit to 1 |
| Clear bit N | `li t2, (1<<N); not t2, t2; and t1, t1, t2` | Force bit to 0 |
| Toggle bit N | `xori t1, t1, (1<<N)` | Flip bit |
| Test bit 31 | `bgez t1, label` | Use sign test |

## Practice Problems

1. How do you test if bit 4 of register t1 is set without changing other bits?
2. Write instructions to set bits 8 and 9 of register t1.
3. Why do we NOT `t2` when clearing a bit?
4. What value is `(1 << 26)`?
5. After `andi t1, t1, 0x20` with t1 = 0xFFFF00FF, what is t1?

### Answers

1. `andi t2, t1, (1 << 4); bnez t2, bit_set_label` — use a different destination to preserve t1, or reuse t1 if you do not need the original value.
2. `ori t1, t1, (3 << 8)` — or — `ori t1, t1, 0x300`
3. Because AND with an inverted mask sets the target bit to 0 while preserving all other bits.  The NOT creates a mask that is all 1s except at the target bit position.
4. 0x04000000 = 67,108,864
5. 0x00000020.  Only bit 5 survives the mask.  Bit 5 of 0xFFFF00FF is in the 0xFF portion, and 0xFF & 0x20 = 0x20.

## Chapter Summary

Bit manipulation is the core skill of peripheral programming.  Test with AND + branch.  Set with OR.  Clear with AND + inverted mask.  Toggle with XOR.  The read-modify-write pattern reads a register, modifies specific bits, and writes it back.  The `bgez` trick tests bit 31 without masking.  Named constants from `constants.s` make bit operations readable.
