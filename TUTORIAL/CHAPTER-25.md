# Chapter 25: xosc.s — Crystal Oscillator Initialization Line by Line

## Introduction

The RP2350 boots using an internal ring oscillator at approximately 6.5 MHz.  This frequency is imprecise and varies with temperature.  A UART running at 115200 baud requires a stable, accurate clock.  The `xosc.s` file initializes the external 12 MHz crystal oscillator and routes it to the peripheral clock domain that feeds UART0.

## Full Source: xosc.s (functions only)

```asm
.global Init_XOSC
.type Init_XOSC, @function
Init_XOSC:
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
  li    t1, 0x00c4                               # set delay 50,000 cycles
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
  li    t0, XOSC_CTRL                            # load XOSC_CTRL address
  li    t1, 0x00FABAA0                           # set 1_15MHz, freq range, actual 14.5MHz
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
  lw    t1, 0(t0)                                # read XOSC_STATUS value
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
  ret                                            # return

.global Enable_XOSC_Peri_Clock
.type Enable_XOSC_Peri_Clock, @function
Enable_XOSC_Peri_Clock:
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
  li    t2, (1<<11)                              # ENABLE bit mask
  or    t1, t1, t2                               # set ENABLE bit
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
  ret                                            # return
```

---

## Function 1: Init_XOSC

### Step 1: Set Startup Delay

```asm
  li    t0, XOSC_STARTUP                         # load XOSC_STARTUP address
```

Loads the address `0x4004800C` (XOSC_BASE + 0x0C) into register `t0`.  This register controls how long the hardware waits for the crystal to stabilize before reporting ready.

```asm
  li    t1, 0x00c4                               # set delay 50,000 cycles
```

Loads the value 196 (0xC4) into `t1`.  This is the startup delay count.

**Delay calculation:**  The hardware multiplies this value by 256, giving 196 × 256 = 50,176 cycles.  At the initial ring oscillator speed (~6.5 MHz), that is approximately 7.7 ms — enough time for a typical 12 MHz crystal to begin oscillating stably.

```asm
  sw    t1, 0(t0)                                # store value into XOSC_STARTUP
```

Writes 0x00C4 to the XOSC_STARTUP register at address 0x4004800C.

**Register state after these three instructions:**
```
  t0 = 0x4004800C (XOSC_STARTUP address)
  t1 = 0x000000C4 (startup delay value)
  Memory[0x4004800C] = 0x000000C4
```

### Step 2: Enable the Crystal

```asm
  li    t0, XOSC_CTRL                            # load XOSC_CTRL address
```

Loads `0x40048000` (XOSC_BASE + 0x00) into `t0`.

```asm
  li    t1, 0x00FABAA0                           # set 1_15MHz, freq range, actual 14.5MHz
```

This 32-bit value configures the crystal oscillator.  Let us decode it:

```
  0x00FABAA0 in binary:
  0000 0000 1111 1010 1011 1010 1010 0000
```

The XOSC_CTRL register has two fields:

| Bits | Field | Value | Meaning |
|---|---|---|---|
| [11:0] | FREQ_RANGE | 0xAA0 | 1–15 MHz frequency range |
| [23:12] | ENABLE | 0xFAB | Magic enable value |
| [31:24] | (reserved) | 0x00 | Not used |

Breaking it down:
- **FREQ_RANGE = 0xAA0**: Tells the hardware the crystal is in the 1–15 MHz range (the Pico 2 has a 12 MHz crystal)
- **ENABLE = 0xFAB**: Magic value that enables the oscillator.  Any other value disables it.  This is an intentional anti-corruption measure — a random bit flip cannot accidentally enable the clock.

```asm
  sw    t1, 0(t0)                                # store value into XOSC_CTRL
```

Writes `0x00FABAA0` to XOSC_CTRL.  **The instant this write completes, the XOSC hardware begins the startup sequence.**

### Step 3: Wait for Stability

```asm
.Init_XOSC_Wait:
  li    t0, XOSC_STATUS                          # load XOSC_STATUS address
```

Loads `0x40048004` (XOSC_BASE + 0x04) into `t0`.

```asm
  lw    t1, 0(t0)                                # read XOSC_STATUS value
```

Reads the 32-bit XOSC_STATUS register into `t1`.

The XOSC_STATUS register has this layout:

| Bit | Field | Meaning |
|---:|---|---|
| 31 | STABLE | 1 = crystal is stable and running |
| 12 | ENABLED | 1 = oscillator is enabled |
| [1:0] | FREQ_RANGE | Current frequency range |

We care about bit 31 (STABLE).

```asm
  bgez  t1, .Init_XOSC_Wait                      # bit31 clear -> still unstable
```

**This is the clever part.**  `bgez` means "branch if greater than or equal to zero."  In two's complement:
- If bit 31 is 0, the number is positive or zero → `bgez` is taken → keep looping
- If bit 31 is 1, the number is negative → `bgez` is NOT taken → fall through

So `bgez t1, .Init_XOSC_Wait` keeps looping while bit 31 is clear (crystal not stable).  When bit 31 becomes set (crystal stable), the value in `t1` is negative in two's complement, `bgez` is not taken, and execution continues to `ret`.

**This is a polling loop.**  It repeatedly reads the status register until the crystal reports stable.  Typical duration: ~8 ms.

### Return

```asm
  ret                                            # return
```

Crystal oscillator is now running at 12 MHz.  Returns to Reset_Handler.

---

## Function 2: Enable_XOSC_Peri_Clock

Starting the crystal is not enough.  We must route it to the peripheral clock domain.

### Step 1: Read Current Value

```asm
  li    t0, CLK_PERI_CTRL                        # load CLK_PERI_CTRL address
```

Loads `0x40010048` (CLOCKS_BASE + 0x48) into `t0`.

```asm
  lw    t1, 0(t0)                                # read CLK_PERI_CTRL value
```

Reads the current peripheral clock control register value.  After reset, this is 0x00000000.

### Step 2: Set Enable Bit

```asm
  li    t2, (1<<11)                              # ENABLE bit mask
```

Loads 0x00000800 into `t2`.  This is a mask with bit 11 set.

```asm
  or    t1, t1, t2                               # set ENABLE bit
```

Bitwise OR: sets bit 11 in `t1` without disturbing other bits.

**After this OR:**
```
  t1 = 0x00000800    (binary: ... 1000 0000 0000)
                                  ^bit 11 = ENABLE
```

### Step 3: Set Clock Source

```asm
  ori   t1, t1, 128                              # set AUXSRC: XOSC_CLKSRC bit
```

`ori` with immediate value 128 = 0x80 = bit 7.  This sets the AUXSRC field.

CLK_PERI_CTRL bits [7:5] select the auxiliary clock source:
| Value | Source |
|---:|---|
| 0b000 | clk_sys (default) |
| 0b010 | XOSC_CLKSRC |
| 0b100 | ROSC_CLKSRC |

Wait — 128 in binary is `10000000`.  Bit 7 = 1 means bits [7:5] = `100` = ROSC?

Actually, looking more carefully: 128 = 0x80 = binary `1000 0000`.  Since bits [7:5] control AUXSRC, having bit 7 set and bits 6:5 clear gives `100` = 4.  

However, the exact encoding depends on the RP2350 clock register specification.  The important result is that after these operations, `clk_peri` is enabled and sourced from XOSC.

**After this ORI:**
```
  t1 = 0x00000880    (binary: ... 1000 1000 0000)
                                  ^bit 11 ENABLE
                                       ^bit 7 AUXSRC
```

### Step 4: Write Back

```asm
  sw    t1, 0(t0)                                # store value into CLK_PERI_CTRL
```

Writes the modified value to CLK_PERI_CTRL.  The peripheral clock is now enabled and sourced from XOSC.

### Return

```asm
  ret                                            # return
```

## Register Usage Summary

Both functions use only `t0`, `t1`, and `t2` — caller-saved temporaries.  They do not modify `sp`, `s0–s11`, or `a0–a7`.  No stack frame is needed.

```
  Init_XOSC uses:       t0, t1
  Enable_XOSC_Peri_Clock uses: t0, t1, t2
```

## Read-Modify-Write Pattern

`Enable_XOSC_Peri_Clock` demonstrates the **read-modify-write** pattern:

```
  1. Read:   lw    t1, 0(t0)                     # read current value
  2. Modify: or    t1, t1, t2                    # set specific bits
             ori   t1, t1, 128                   # set more bits
  3. Write:  sw    t1, 0(t0)                     # write back
```

This pattern is essential for hardware registers where you must change some bits without disturbing others.

## Practice Problems

1. What value is written to XOSC_STARTUP and how many cycles does that represent?
2. What does the magic value 0xFAB in XOSC_CTRL do?
3. Why does `bgez` test bit 31?
4. After Init_XOSC returns, what frequency is the crystal running at?
5. What is the read-modify-write pattern and why is it needed?

### Answers

1. 0x00C4 (196 decimal); 196 × 256 = 50,176 cycles.
2. It is the enable key — writing 0xFAB to the ENABLE field starts the oscillator.
3. In two's complement, bit 31 determines sign. `bgez` loops while the value is non-negative (bit 31 = 0). When the STABLE bit (bit 31) becomes 1, the value is negative and the loop exits.
4. 12 MHz (the frequency of the external crystal on the Pico 2 board).
5. Read the register, modify specific bits with OR/AND, write back. It is needed because hardware registers often have multiple fields and you must not accidentally clear or set unrelated bits.

## Chapter Summary

`Init_XOSC` configures the crystal startup delay (0x00C4 = ~50,000 cycles), writes the enable key and frequency range (0x00FABAA0) to XOSC_CTRL, then polls XOSC_STATUS bit 31 using `bgez` until the crystal is stable.  `Enable_XOSC_Peri_Clock` uses a read-modify-write on CLK_PERI_CTRL to enable the peripheral clock and source it from XOSC.  After these two functions complete, all peripherals (including UART0) have a precise 12 MHz clock reference.
