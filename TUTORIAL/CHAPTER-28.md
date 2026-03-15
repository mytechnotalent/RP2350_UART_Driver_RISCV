# Chapter 28: uart.s Part 2 — Transmit and Receive

## Introduction

With UART0 initialized and running (Chapter 27), we can now send and receive bytes.  The PL011 UART uses FIFOs (first-in, first-out buffers) and flag bits to coordinate data flow.  This chapter walks through `UART0_Out` (blocking transmit) and `UART0_In` (blocking receive), explaining every instruction and the hardware protocol they implement.

## Function 1: UART0_Out — Blocking Transmit

### Full Source

```asm
.global UART0_Out
.type UART0_Out, @function
UART0_Out:
.UART0_Out_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
  lw    t1, 0x18(t0)                             # read UARTFR
  andi  t1, t1, 32                               # mask TXFF bit
  bnez  t1, .UART0_Out_loop                      # if TX FIFO is full, loop
  andi  a0, a0, 0xff                             # keep lower 8 bits only
  sw    a0, 0x00(t0)                             # write data to UARTDR
  ret                                            # return
```

### Parameters

On entry, `a0` contains the byte to transmit.  Only the lower 8 bits are used.

### Line-by-Line

```asm
.UART0_Out_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
```

Loads 0x40070000 into `t0`.  Note this is INSIDE the loop — `t0` is reloaded every iteration.  This is safe (no side effects) and avoids needing to save `t0` across the loop.

```asm
  lw    t1, 0x18(t0)                             # read UARTFR
```

Reads UARTFR (Flag Register) at offset 0x18 from UART0_BASE = address 0x40070018.

The Flag Register is a read-only register with these bits:

| Bit | Name | Meaning |
|---:|---|---|
| 0 | CTS | Clear to send |
| 3 | BUSY | UART is transmitting data |
| 4 | RXFE | RX FIFO empty |
| **5** | **TXFF** | **TX FIFO full** |
| 6 | RXFF | RX FIFO full |
| 7 | TXFE | TX FIFO empty |

We care about bit 5, TXFF.

```asm
  andi  t1, t1, 32                               # mask TXFF bit
```

32 = `0b100000` = bit 5.  After AND:
- If TXFF=1 (FIFO full): `t1` = 32 (non-zero)
- If TXFF=0 (FIFO has space): `t1` = 0

```asm
  bnez  t1, .UART0_Out_loop                      # if TX FIFO is full, loop
```

If `t1` is non-zero (FIFO full), loop back and check again.  This is a **busy-wait**: the CPU repeatedly polls the flag register until the TX FIFO has room.

**When does the FIFO have room?**  The UART hardware continuously shifts data out of the TX FIFO at baud rate.  Each character at 115200 baud 8N1 takes 10 bit-times = 86.8 µs.  With a 32-entry FIFO, it can take up to ~2.8 ms to drain if full.

Once the FIFO has at least one empty slot, TXFF clears to 0 and we fall through.

```asm
  andi  a0, a0, 0xff                             # keep lower 8 bits only
```

Masks `a0` to 8 bits.  If the caller passed a value like 0x00000141 ('A' with upper bits), this ensures only 0x41 is transmitted.  The UART is configured for 8-bit words, so bits [31:8] of the data register are ignored by hardware — this mask is a safety measure.

```asm
  sw    a0, 0x00(t0)                             # write data to UARTDR
```

Writes to UARTDR (Data Register) at offset 0x00 from UART0_BASE = address 0x40070000.

**When you write to UARTDR, the byte is placed into the TX FIFO.**  The hardware will then:
1. Serialize the byte: idle (high) → start bit (low) → 8 data bits (LSB first) → stop bit (high)
2. Shift the bits out on the TX pin (GPIO0) at 115200 bits/second
3. Move to the next FIFO entry

```asm
  ret                                            # return
```

Returns to caller.  Note: the byte may still be in the FIFO being transmitted.  `ret` does NOT wait for the transmission to complete — it only waits for FIFO space.

### Timing

At 115200 baud, 8N1 = 10 bits per character:

$$t_{char} = \frac{10}{115200} = 86.8 \mu s$$

With a 32-entry FIFO, you can write 32 characters in rapid succession before the FIFO fills.  The 33rd write will busy-wait until the first character finishes transmitting.

---

## Function 2: UART0_In — Blocking Receive

### Full Source

```asm
.global UART0_In
.type UART0_In, @function
UART0_In:
.UART0_In_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
  lw    t1, 0x18(t0)                             # read UARTFR
  andi  t1, t1, 16                               # mask RXFE bit
  bnez  t1, .UART0_In_loop                       # if RX FIFO is empty, loop
  lw    a0, 0x00(t0)                             # load data from UARTDR into a0
  andi  a0, a0, 0xff                             # keep lower 8 bits valid
  ret                                            # return
```

### Parameters

On entry: no parameters.  
On exit: `a0` contains the received byte (lower 8 bits).

### Line-by-Line

```asm
.UART0_In_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
```

Same pattern as UART0_Out — load base address inside the loop.

```asm
  lw    t1, 0x18(t0)                             # read UARTFR
```

Read the Flag Register at 0x40070018.

This time we care about bit 4, RXFE (RX FIFO Empty):

| Bit | Name | Meaning when 1 |
|---:|---|---|
| 4 | RXFE | RX FIFO is empty (no data available) |

```asm
  andi  t1, t1, 16                               # mask RXFE bit
```

16 = `0b10000` = bit 4.  After AND:
- If RXFE=1 (FIFO empty): `t1` = 16 (non-zero) → no data to read
- If RXFE=0 (FIFO has data): `t1` = 0 → data available

```asm
  bnez  t1, .UART0_In_loop                       # if RX FIFO is empty, loop
```

If the RX FIFO is empty, loop back and keep polling.  **This is where the CPU blocks**, waiting for the remote end (your terminal) to send a character.

**What fills the RX FIFO?**  When the external device sends a byte over the serial line, the UART hardware on GPIO1 (RX pin):
1. Detects the start bit (falling edge)
2. Samples each data bit at the center of the bit period
3. Checks the stop bit
4. Places the assembled byte into the RX FIFO
5. Clears the RXFE flag

This happens entirely in hardware, with no CPU involvement.  The CPU just checks whether data has arrived by reading the flag register.

```asm
  lw    a0, 0x00(t0)                             # load data from UARTDR into a0
```

Reads UARTDR at 0x40070000.  When reading UARTDR:
- Bits [7:0]: received data byte
- Bits [11:8]: error flags (framing, parity, break, overrun)
- Bits [31:12]: reserved

**Reading UARTDR pops the frontmost byte from the RX FIFO.**  If there were 5 bytes waiting, after this read there are 4.

```asm
  andi  a0, a0, 0xff                             # keep lower 8 bits valid
```

Masks off the error bits [11:8] and reserved bits [31:12], keeping only the 8-bit data value.  This means our firmware silently ignores any framing or parity errors.

```asm
  ret                                            # return
```

Returns with the received byte in `a0`.

---

## The Echo Loop

Together, these two functions implement the echo behavior when called from `main.s`:

```asm
.Loop:
  call  UART0_In                                 # wait for and read a byte → a0
  call  UART0_Out                                # send that byte back → TX
  j     .Loop                                    # repeat forever
```

The data flow:

```
  1. Terminal user types 'A' (0x41)
  2. Terminal sends:  [start bit][0x41 LSB-first][stop bit] over serial line
  3. UART hardware receives on GPIO1, assembles 0x41, puts in RX FIFO
  4. UART0_In reads UARTFR, sees RXFE=0, reads UARTDR → a0 = 0x41
  5. UART0_Out polls UARTFR, sees TXFF=0, writes a0 (0x41) to UARTDR
  6. UART hardware takes 0x41 from TX FIFO, serializes on GPIO0
  7. USB-serial adapter receives the bits, sends to terminal
  8. Terminal displays 'A'
```

Round-trip latency: approximately 170 µs (two character times at 115200 baud) plus CPU processing (negligible at 12 MHz).

## The UARTDR Register: Dual-Purpose

Address 0x40070000 (UARTDR) behaves differently for reads and writes:

| Operation | Behavior |
|---|---|
| `sw` (write) | Places byte into TX FIFO for transmission |
| `lw` (read) | Pops byte from RX FIFO |

This is common in UART hardware — a single address serves as both the transmit data input and receive data output.  The hardware routes the access to the appropriate FIFO based on read vs. write.

## Register Usage

Both functions use only `t0`, `t1`, and `a0`:

```
  UART0_Out:
    t0 = UART0_BASE address
    t1 = UARTFR value (for polling)
    a0 = input parameter (byte to send), masked to 8 bits

  UART0_In:
    t0 = UART0_BASE address
    t1 = UARTFR value (for polling)
    a0 = output (received byte)
```

No callee-saved registers are used.  No stack frame is needed.

## Potential Issues

1. **Blocking forever**: If no data arrives, `UART0_In` blocks forever.  There is no timeout.  In a production system, you might add a timeout counter.

2. **Overrun**: If data arrives faster than the firmware reads it, the 32-byte RX FIFO fills up.  Additional characters cause an overrun error (UARTDR bit 11).  Our firmware ignores this flag.

3. **FIFO reload inside loop**: `li t0, UART0_BASE` is inside the loop body, executing every iteration.  This costs 1-2 extra instructions per iteration but simplifies the code.

## Practice Problems

1. Which UARTFR bit indicates the TX FIFO is full?
2. Which UARTFR bit indicates the RX FIFO is empty?
3. What does writing to UARTDR do?
4. What does reading from UARTDR do?
5. How long does it take to transmit one character at 115200 baud 8N1?

### Answers

1. Bit 5 (TXFF), tested with `andi t1, t1, 32`.
2. Bit 4 (RXFE), tested with `andi t1, t1, 16`.
3. Places the byte into the TX FIFO for serialization and transmission on the TX pin.
4. Pops the oldest byte from the RX FIFO (received from the RX pin).
5. 10 bits / 115200 baud = 86.8 µs per character.

## Chapter Summary

`UART0_Out` polls UARTFR bit 5 (TXFF) in a busy loop until the TX FIFO has space, masks `a0` to 8 bits, and writes to UARTDR.  `UART0_In` polls UARTFR bit 4 (RXFE) until data is available, reads UARTDR to pop a byte from the RX FIFO, and masks to 8 bits.  Together, they implement blocking serial I/O.  The echo loop in main simply pipes every received byte back out, creating a character-by-character echo visible in any terminal program.
