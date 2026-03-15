# Chapter 26: reset.s — Releasing IO_BANK0 from Reset

## Introduction

When the RP2350 powers on, most peripherals are held in hardware reset to save power and prevent undefined behavior.  Before you can access any GPIO register, you must explicitly release IO_BANK0 from reset and wait for the hardware to confirm the release is complete.  This chapter explains every line of `reset.s`.

## Full Source: reset.s (function only)

```asm
.global Init_Subsystem
.type Init_Subsystem, @function
Init_Subsystem:
.GPIO_Subsystem_Reset:
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
  li    t2, (1<<6)                               # IO_BANK0 reset mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear IO_BANK0 bit
  sw    t1, 0(t0)                                # store value into RESETS->RESET address
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
  ret                                            # return
```

## Background: The Reset Controller

The RP2350 has a reset controller at address 0x40020000.  It contains a 32-bit register where each bit controls the reset state of one peripheral:

| Bit | Peripheral |
|---:|---|
| 0 | ADC |
| 1 | BUSCTRL |
| 2 | DMA |
| 5 | IO_QSPI |
| **6** | **IO_BANK0** |
| 8 | PADS_BANK0 |
| 9 | PADS_QSPI |
| 10 | PIO0 |
| 22 | SPI0 |
| 24 | TIMER0 |
| **26** | **UART0** |
| 27 | UART1 |

When a bit is **1**, that peripheral is **held in reset** (disabled).  When a bit is **0**, the peripheral is **released** and operational.

After power-on, most bits start as 1 (held in reset).

## Line-by-Line Walkthrough

### Label: Init_Subsystem

```asm
Init_Subsystem:
.GPIO_Subsystem_Reset:
```

Two labels at the same address.  `Init_Subsystem` is the global function name (exported with `.global`).  `.GPIO_Subsystem_Reset` is a local label documenting what this section does.

### Step 1: Load Register Address

```asm
  li    t0, RESETS_RESET                         # load RESETS->RESET address
```

Loads 0x40020000 (RESETS_BASE + 0x00) into `t0`.  This is the main reset control register.

The `li` pseudoinstruction expands to:
```asm
  lui   t0, 0x40020                              # t0 = 0x40020000
```

(Since the lower 12 bits are zero, `addi` is optimized away.)

### Step 2: Read Current Value

```asm
  lw    t1, 0(t0)                                # read RESETS->RESET value
```

Reads the 32-bit reset register into `t1`.  After power-on, many bits are 1, indicating those peripherals are in reset.

For example, `t1` might contain `0x1FFFFFFF` — all peripherals in reset.

### Step 3: Create Bit Mask

```asm
  li    t2, (1<<6)                               # IO_BANK0 reset mask
```

Creates a mask with only bit 6 set:
```
  t2 = 0x00000040 = binary  0000...0100 0000
                                    ^bit 6
```

### Step 4: Invert the Mask

```asm
  not   t2, t2                                   # invert mask
```

`not` is a pseudoinstruction that expands to `xori t2, t2, -1` (XOR with all ones).

```
  Before: t2 = 0x00000040 = 0000...0100 0000
  After:  t2 = 0xFFFFFFBF = 1111...1011 1111
                                    ^bit 6 is now 0
```

This creates a mask where every bit is 1 **except** bit 6.

### Step 5: Clear the Bit

```asm
  and   t1, t1, t2                               # clear IO_BANK0 bit
```

Bitwise AND:
```
  t1 (register value): xxxx...x1xx xxxx   (bit 6 was 1)
  t2 (inverted mask):  1111...1011 1111   (bit 6 is 0)
  Result:              xxxx...x0xx xxxx   (bit 6 forced to 0)
```

All other bits remain unchanged.  Only bit 6 is forced to 0.

**Why AND with inverted mask?**  To clear a single bit, you AND with a mask that has that bit as 0 and all others as 1.  The three-step pattern is:
1. Create mask: `li t2, (1<<N)`
2. Invert: `not t2, t2`
3. AND: `and t1, t1, t2`

This clears bit N while preserving all other bits.

### Step 6: Write Back

```asm
  sw    t1, 0(t0)                                # store value into RESETS->RESET address
```

Writes the modified value back.  With bit 6 now 0, the hardware begins releasing IO_BANK0 from reset.

**This does NOT happen instantly.**  The hardware needs time to initialize IO_BANK0's internal logic, clock gates, and register files.  We must wait.

### Step 7: Load Done Register Address

```asm
.GPIO_Subsystem_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
```

Loads 0x40020008 (RESETS_BASE + 0x08) into `t0`.  This read-only register indicates which peripherals have completed their reset release.

### Step 8: Read Done Status

```asm
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
```

Reads the 32-bit reset-done register into `t1`.  Each bit is 1 when the corresponding peripheral has finished coming out of reset.

### Step 9: Test Bit 6

```asm
  andi  t1, t1, (1<<6)                           # test IO_BANK0 reset done
```

Bitwise AND with immediate `(1<<6)` = 64:
```
  t1 (done register):  xxxx...xYxx xxxx
  Immediate mask:       0000...0100 0000
  Result:               0000...0Y00 0000
```

If bit 6 (Y) is 0, the result is 0 — IO_BANK0 is not ready yet.  
If bit 6 (Y) is 1, the result is 64 (non-zero) — IO_BANK0 is ready.

### Step 10: Loop or Continue

```asm
  beqz  t1, .GPIO_Subsystem_Reset_Wait           # wait until done
```

If `t1` is zero (bit 6 was 0), branch back to re-read.  This creates a polling loop.

If `t1` is non-zero (bit 6 was 1), fall through to `ret`.

### Return

```asm
  ret                                            # return
```

IO_BANK0 is now out of reset.  All GPIO control registers are accessible.

## The Bit-Clear Pattern in Detail

This function demonstrates the **clear-a-bit-by-AND-with-inverted-mask** pattern:

```
  Step 1:  li    t2, (1<<6)                      # t2 = 0x00000040
  Step 2:  not   t2, t2                          # t2 = 0xFFFFFFBF
  Step 3:  and   t1, t1, t2                      # bit 6 cleared
```

Compare with chapter 16 where we learned:
- **Set a bit**: `or value, value, mask`
- **Clear a bit**: `and value, value, NOT(mask)`
- **Test a bit**: `and result, value, mask` then check if zero

This function uses all three patterns:
- Clear bit: AND with inverted mask (lines 3–5)
- Test bit: `andi` with mask (line 9)
- Branch on test: `beqz` (line 10)

## The Polling Pattern

```
  loop_start:
    li    t0, STATUS_REGISTER                    # load address
    lw    t1, 0(t0)                              # read status
    andi  t1, t1, BIT_MASK                       # test specific bit
    beqz  t1, loop_start                         # loop if not ready
```

This pattern appears in every hardware driver:
1. Read a status register
2. Test a specific bit
3. Loop until the bit shows the desired state

It is called **busy-waiting** or **polling**.  The CPU does nothing useful while waiting, but for short hardware delays (microseconds to milliseconds), it is the simplest approach.

## Register Usage

```
  t0: address register (RESETS_RESET, then RESETS_RESET_DONE)
  t1: data register (register value, then done status)
  t2: mask register
```

All temporaries.  No callee-saved registers used, no stack frame needed.

## Practice Problems

1. What specific bit in RESETS_RESET corresponds to IO_BANK0?
2. If you skipped the `not t2, t2` step and used `and t1, t1, t2` directly with `(1<<6)`, what would happen?
3. Why can't you just write 0 to the entire RESETS_RESET register?
4. What does RESETS_RESET_DONE bit 6 = 1 mean?
5. How many iterations does the polling loop typically take?

### Answers

1. Bit 6.
2. AND with `0x00000040` would clear all bits EXCEPT bit 6 — the opposite of what we want; it would put every other peripheral into reset while keeping IO_BANK0 in reset.
3. Writing 0 would release ALL peripherals from reset simultaneously, which wastes power and may cause initialization conflicts.  We only release what we need.
4. IO_BANK0 has successfully completed its reset sequence and its registers are now accessible.
5. Typically very few (1–10 iterations).  The hardware takes only a few clock cycles to release a peripheral from reset.

## Chapter Summary

`Init_Subsystem` releases IO_BANK0 from hardware reset using a read-modify-write sequence: read RESETS_RESET, create mask `(1<<6)`, invert it, AND to clear bit 6, write back.  It then polls RESETS_RESET_DONE bit 6 in a busy-wait loop until the hardware confirms IO_BANK0 is operational.  This is a prerequisite for any GPIO register access.
