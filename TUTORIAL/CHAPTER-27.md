# Chapter 27: uart.s Part 1 — Release Reset and Initialization

## Introduction

This is the largest and most complex source file in the firmware.  It contains four functions.  This chapter covers the first two: `UART_Release_Reset` (releasing UART0 from hardware reset) and `UART_Init` (configuring pins, baud rate, and enabling the transceiver).  Chapter 28 covers the transmit and receive functions.

## Function 1: UART_Release_Reset

### Full Source

```asm
.global UART_Release_Reset
.type UART_Release_Reset, @function
UART_Release_Reset:
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
  li    t2, (1<<26)                              # UART0 reset bit mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear UART0 reset bit
  sw    t1, 0(t0)                                # write value back to RESETS->RESET
.UART_Release_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  li    t2, (1<<26)                              # UART0 done mask
  and   t1, t1, t2                               # test UART0 reset-done bit
  beqz  t1, .UART_Release_Reset_Wait             # loop until UART0 is out of reset
  ret                                            # return
```

### Line-by-Line

This function follows the exact same pattern as `Init_Subsystem` in Chapter 26, but targets **bit 26** (UART0) instead of bit 6 (IO_BANK0).

```asm
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
```

Load the address 0x40020000 and read the 32-bit reset register.

```asm
  li    t2, (1<<26)                              # UART0 reset bit mask
```

Create a mask with only bit 26 set:
```
  t2 = 0x04000000 = binary  0000 0100 0000 0000 0000 0000 0000 0000
                                  ^bit 26
```

```asm
  not   t2, t2                                   # invert mask
```

```
  t2 = 0xFBFFFFFF = 1111 1011 1111...
                          ^bit 26 is 0
```

```asm
  and   t1, t1, t2                               # clear UART0 reset bit
  sw    t1, 0(t0)                                # write value back to RESETS->RESET
```

Clear bit 26, write back.  UART0 begins coming out of reset.

### Polling Loop

```asm
.UART_Release_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  li    t2, (1<<26)                              # UART0 done mask
  and   t1, t1, t2                               # test UART0 reset-done bit
  beqz  t1, .UART_Release_Reset_Wait             # loop until UART0 is out of reset
```

Note a subtle difference from `Init_Subsystem`: here we use `and t1, t1, t2` instead of `andi t1, t1, (1<<26)`.  Why?

`andi` takes a 12-bit sign-extended immediate.  The range is -2048 to +2047.  `(1<<26)` = 67,108,864 — far too large for a 12-bit immediate.  So the mask must be loaded into a register and AND'd with register-register `and`.

In contrast, `Init_Subsystem` used `andi t1, t1, (1<<6)` = `andi t1, t1, 64` — 64 fits in a 12-bit immediate.

```asm
  ret                                            # return
```

UART0 is now out of reset.  Its registers are accessible.

---

## Function 2: UART_Init

### Full Source

```asm
.global UART_Init
.type UART_Init, @function
UART_Init:
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
  li    t1, 2                                    # FUNCSEL = 2 -> select UART function
  sw    t1, 0x04(t0)                             # write FUNCSEL to GPIO0_CTRL (pin0 -> TX)
  sw    t1, 0x0c(t0)                             # write FUNCSEL to GPIO1_CTRL (pin1 -> RX)
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0 base
  li    t1, 0x04                                 # pad config value for TX
  sw    t1, 0x04(t0)                             # write PAD0 config (TX pad)
  li    t1, 0x40                                 # pad config value for RX
  sw    t1, 0x08(t0)                             # write PAD1 config (RX pad)
  li    t0, UART0_BASE                           # load UART0 base address
  li    t1, 0                                    # prepare 0 to disable UARTCR
  sw    t1, 0x30(t0)                             # UARTCR = 0 (disable UART while configuring)
  li    t1, 6                                    # integer baud divisor (IBRD = 6)
  sw    t1, 0x24(t0)                             # UARTIBRD = 6
  li    t1, 33                                   # fractional baud divisor (FBRD = 33)
  sw    t1, 0x28(t0)                             # UARTFBRD = 33
  li    t1, 112                                  # UARTLCR_H = 0x70 (FIFO enable + 8-bit)
  sw    t1, 0x2c(t0)                             # UARTLCR_H = 0x70
  li    t1, ((3<<8) | 1)                         # UARTEN + TXE + RXE
  sw    t1, 0x30(t0)                             # UARTCR = enable
  ret                                            # return
```

This function has three phases: GPIO pin configuration, pad configuration, and UART register configuration.

---

### Phase 1: GPIO Function Select

#### Set GPIO0 as UART TX

```asm
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
```

Loads 0x40028000 into `t0`.  This is the base of the GPIO function control registers.

```asm
  li    t1, 2                                    # FUNCSEL = 2 -> select UART function
```

Each GPIO pin can serve multiple functions.  The FUNCSEL field selects which peripheral drives the pin:

| FUNCSEL | Function for GPIO0 | Function for GPIO1 |
|---:|---|---|
| 0 | JTAG TCK | JTAG TMS |
| 1 | SPI0 RX | SPI0 CSn |
| **2** | **UART0 TX** | **UART0 RX** |
| 3 | I2C0 SDA | I2C0 SCL |
| 5 | SIO | SIO |
| 31 | NULL | NULL |

Value 2 selects the UART function for both GPIO0 and GPIO1.

```asm
  sw    t1, 0x04(t0)                             # write FUNCSEL to GPIO0_CTRL (pin0 -> TX)
```

GPIO0_CTRL is at IO_BANK0_BASE + 0x04 = 0x40028004.  Writing 2 to this register makes GPIO0 function as UART0 TX.

The register layout of each GPIOx_CTRL:
```
  Bits [4:0] = FUNCSEL (function select)
  Bits [13:12] = OUTOVER (output override)
  Bits [17:16] = OEOVER (output enable override)
  Bits [29:28] = IRQOVER (interrupt override)
```

We write just `2`, which sets FUNCSEL=2 and clears all override bits — normal operation.

```asm
  sw    t1, 0x0c(t0)                             # write FUNCSEL to GPIO1_CTRL (pin1 -> RX)
```

GPIO1_CTRL is at IO_BANK0_BASE + 0x0C = 0x4002800C.  Same value (2) makes GPIO1 function as UART0 RX.

**Why 0x04 and 0x0C?**  Each GPIO has two registers:
- GPIOx_STATUS at offset 8×x + 0x00
- GPIOx_CTRL at offset 8×x + 0x04

For GPIO0: STATUS=0x00, CTRL=0x04.  For GPIO1: STATUS=0x08, CTRL=0x0C.

---

### Phase 2: Pad Configuration

```asm
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0 base
```

Loads 0x40038000.  The pad controller sets electrical characteristics: drive strength, pull-ups, pull-downs, input enable, output disable, Schmitt trigger, slew rate.

#### TX Pad (GPIO0)

```asm
  li    t1, 0x04                                 # pad config value for TX
  sw    t1, 0x04(t0)                             # write PAD0 config (TX pad)
```

PAD0 is at PADS_BANK0_BASE + 0x04 = 0x40038004.

Value 0x04 in binary: `0000 0100`

| Bit | Field | Value | Meaning |
|---:|---|---:|---|
| 0 | SLEWFAST | 0 | Slow slew rate |
| 1 | SCHMITT | 0 | Schmitt trigger disabled |
| 2 | PDE | 1 | Pull-down enabled |
| 3 | PUE | 0 | Pull-up disabled |
| [5:4] | DRIVE | 00 | 2 mA drive strength |
| 6 | IE | 0 | **Input disabled** |
| 7 | OD | 0 | **Output enabled** |

Key insight: TX pad has output enabled (OD=0) and input disabled (IE=0) because it only transmits.

#### RX Pad (GPIO1)

```asm
  li    t1, 0x40                                 # pad config value for RX
  sw    t1, 0x08(t0)                             # write PAD1 config (RX pad)
```

PAD1 is at PADS_BANK0_BASE + 0x08 = 0x40038008.

Value 0x40 in binary: `0100 0000`

| Bit | Field | Value | Meaning |
|---:|---|---:|---|
| 0 | SLEWFAST | 0 | Slow slew rate |
| 1 | SCHMITT | 0 | Schmitt trigger disabled |
| 2 | PDE | 0 | Pull-down disabled |
| 3 | PUE | 0 | Pull-up disabled |
| [5:4] | DRIVE | 00 | 2 mA |
| 6 | IE | 1 | **Input enabled** |
| 7 | OD | 0 | Output enabled |

Key insight: RX pad has input enabled (IE=1) because it receives external signals.

---

### Phase 3: UART Configuration

#### Disable UART Before Configuration

```asm
  li    t0, UART0_BASE                           # load UART0 base address
```

Loads 0x40070000.

```asm
  li    t1, 0                                    # prepare 0 to disable UARTCR
  sw    t1, 0x30(t0)                             # UARTCR = 0 (disable UART while configuring)
```

UARTCR (Control Register) at offset 0x30.  Writing 0 disables everything (UART enable, TX enable, RX enable all cleared).

**Why disable first?**  The PL011 UART specification requires the UART to be disabled when changing baud rate or line control settings.  Making changes while enabled can cause corrupted characters on the TX line.

#### Set Integer Baud Divisor

```asm
  li    t1, 6                                    # integer baud divisor (IBRD = 6)
  sw    t1, 0x24(t0)                             # UARTIBRD = 6
```

UARTIBRD at offset 0x24.  This is the integer part of the baud rate divisor.

#### Set Fractional Baud Divisor

```asm
  li    t1, 33                                   # fractional baud divisor (FBRD = 33)
  sw    t1, 0x28(t0)                             # UARTFBRD = 33
```

UARTFBRD at offset 0x28.  This is the fractional part (6-bit field, range 0–63).

#### Baud Rate Calculation

The PL011 baud rate formula:

$$\text{Baud Divisor} = \frac{f_{UARTCLK}}{16 \times \text{Baud Rate}}$$

With:
- $f_{UARTCLK}$ = 12,000,000 Hz (XOSC frequency)
- Baud Rate = 115,200

$$\text{Divisor} = \frac{12{,}000{,}000}{16 \times 115{,}200} = \frac{12{,}000{,}000}{1{,}843{,}200} = 6.5104...$$

Split into integer and fractional parts:
- Integer: 6
- Fractional: 0.5104... × 64 = 32.67 ≈ 33

So IBRD = 6 and FBRD = 33.

**Verification:** actual baud rate:
$$\text{Actual Divisor} = 6 + \frac{33}{64} = 6.515625$$
$$\text{Actual Baud} = \frac{12{,}000{,}000}{16 \times 6.515625} = \frac{12{,}000{,}000}{104.25} = 115{,}107.9...$$

Error: $(115200 - 115108) / 115200 = 0.08\%$ — well within the UART tolerance of ±3%.

#### Set Line Control

```asm
  li    t1, 112                                  # UARTLCR_H = 0x70 (FIFO enable + 8-bit)
  sw    t1, 0x2c(t0)                             # UARTLCR_H = 0x70
```

UARTLCR_H at offset 0x2C.  Value 112 = 0x70 in binary: `0111 0000`.

| Bit | Field | Value | Meaning |
|---:|---|---:|---|
| 0 | BRK | 0 | No break signal |
| 1 | PEN | 0 | Parity disabled |
| 2 | EPS | 0 | (ignored, parity off) |
| 3 | STP2 | 0 | 1 stop bit |
| 4 | FEN | 1 | **FIFO enabled** |
| [6:5] | WLEN | 11 | **8-bit word length** |
| 7 | SPS | 0 | No stick parity |

- **FEN = 1** (bit 4): Enables the 32-byte TX and RX FIFOs.  Without FIFOs, the UART can only buffer 1 character.
- **WLEN = 11** (bits 6:5): 8-bit data words, the standard for virtually all modern serial communication.

Combined: 8 data bits, no parity, 1 stop bit = **8N1**.

#### Enable UART

```asm
  li    t1, ((3<<8) | 1)                         # UARTEN + TXE + RXE
  sw    t1, 0x30(t0)                             # UARTCR = enable
```

Let us compute `((3<<8) | 1)`:

```
  3 << 8 = 0x300 = binary 0000 0011 0000 0000
  | 1    = 0x301 = binary 0000 0011 0000 0001
```

UARTCR bit map:

| Bit | Field | Value | Meaning |
|---:|---|---:|---|
| 0 | UARTEN | 1 | **UART enabled** |
| 8 | TXE | 1 | **Transmit enabled** |
| 9 | RXE | 1 | **Receive enabled** |

Writing 0x301 to UARTCR starts the UART:
- UARTEN (bit 0) = 1: master enable
- TXE (bit 8) = 1: transmitter active
- RXE (bit 9) = 1: receiver active

**After this write, the UART is live.**  Any data arriving on GPIO1 (RX) will be captured into the RX FIFO.

### Return

```asm
  ret                                            # return
```

## Register Map Summary

All UART0 registers used, relative to UART0_BASE (0x40070000):

| Offset | Register | Purpose | Value Written |
|---:|---|---|---:|
| 0x00 | UARTDR | Data register | (TX/RX data) |
| 0x18 | UARTFR | Flag register | (read-only) |
| 0x24 | UARTIBRD | Integer baud divisor | 6 |
| 0x28 | UARTFBRD | Fractional baud divisor | 33 |
| 0x2C | UARTLCR_H | Line control | 0x70 |
| 0x30 | UARTCR | Control register | 0x301 |

## Practice Problems

1. Why is `and` used instead of `andi` for testing bit 26 in UART_Release_Reset?
2. What happens if you skip the UARTCR=0 step?
3. Calculate the baud rate if IBRD=13 and FBRD=1 with a 12 MHz clock.
4. What does WLEN=11 in UARTLCR_H mean?
5. What three bits must be set in UARTCR to enable full duplex UART?

### Answers

1. `(1<<26)` = 67,108,864, which does not fit in a 12-bit sign-extended immediate. `andi` can only handle values -2048 to +2047.
2. The baud rate and line control changes may produce garbled output because the UART is still transmitting with old settings.
3. Divisor = 13 + 1/64 = 13.015625; Baud = 12,000,000 / (16 × 13.015625) = 57,623 ≈ **57,600 baud**.
4. 8-bit word length (the standard for modern serial communication).
5. UARTEN (bit 0), TXE (bit 8), RXE (bit 9) = 0x301.

## Chapter Summary

`UART_Release_Reset` clears bit 26 in RESETS_RESET to bring UART0 out of hardware reset, then polls RESETS_RESET_DONE bit 26.  `UART_Init` configures GPIO0/1 for UART function (FUNCSEL=2), sets pad characteristics (TX=output, RX=input), disables the UART, programs baud divisors (IBRD=6, FBRD=33 for 115200 baud at 12 MHz), enables FIFOs with 8-bit words (LCR_H=0x70), and finally enables the UART with TX and RX active (CR=0x301).
