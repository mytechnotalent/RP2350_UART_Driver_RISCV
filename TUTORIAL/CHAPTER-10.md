# Chapter 10: RISC-V Memory Access Instructions — Load and Store Deep Dive

## Introduction

Chapter 5 introduced the load-store concept.  This chapter exhaustively covers every load and store instruction variant, their encodings, alignment requirements, and exactly how they are used throughout our firmware.

## Load Instruction Family

Every load follows the I-type format:

```
  [imm[11:0] | rs1 | funct3 | rd | opcode=0000011]
```

### LW: Load Word (4 bytes)

```asm
  lw    rd, offset(rs1)                          # rd = memory[rs1 + offset] (4 bytes)
```

This is the workhorse of our firmware.  Every peripheral register read uses `lw`:

```asm
  li    t0, UART0_BASE                           # t0 = 0x40070000
  lw    t1, UARTFR(t0)                           # t1 = memory[0x40070018] (flag reg)
```

The CPU:
1. Reads `t0` (value 0x40070000)
2. Adds sign-extended offset `0x18` (value 24)
3. Effective address = 0x40070018
4. Reads 4 bytes from that address (little-endian)
5. Writes the 32-bit value into `t1`

**Alignment**: the effective address MUST be divisible by 4.  Misaligned `lw` may cause an exception.

### LH: Load Halfword (2 bytes, sign-extended)

```asm
  lh    rd, offset(rs1)                          # rd = sign_extend(memory[rs1+offset], 16)
```

Reads 2 bytes.  If bit 15 of the halfword is 1, bits 16-31 of `rd` are filled with 1s.  If bit 15 is 0, bits 16-31 are filled with 0s.

**Alignment**: effective address must be divisible by 2.

### LHU: Load Halfword Unsigned (2 bytes, zero-extended)

```asm
  lhu   rd, offset(rs1)                          # rd = zero_extend(memory[rs1+offset], 16)
```

Same as `lh` but always fills upper 16 bits with zeros.  Use this when the halfword represents an unsigned value.

### LB: Load Byte (1 byte, sign-extended)

```asm
  lb    rd, offset(rs1)                          # rd = sign_extend(memory[rs1+offset], 8)
```

Reads 1 byte.  Sign-extends from 8 bits to 32 bits.

### LBU: Load Byte Unsigned (1 byte, zero-extended)

```asm
  lbu   rd, offset(rs1)                          # rd = zero_extend(memory[rs1+offset], 8)
```

Reads 1 byte.  Zero-extends.  No alignment constraint (any address is fine for bytes).

### Sign Extension in Detail

Why does sign extension matter?  Consider loading the byte value 0xFE:

```
  As unsigned:  0xFE = 254 decimal
  As signed:    0xFE = -2 decimal (two's complement)

  lb:   0xFE → 0xFFFFFFFE (sign-extended, value = -2 in 32-bit)
  lbu:  0xFE → 0x000000FE (zero-extended, value = 254 in 32-bit)
```

If you later use this value in signed arithmetic, `lb` preserves the correct sign.  If you treat it as raw data (like a character), `lbu` is appropriate.

For UART character I/O, zero-extension is correct because ASCII values are unsigned.

## Store Instruction Family

Every store follows the S-type format:

```
  [imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode=0100011]
```

Note: the immediate is split across two fields.  This is because `rd` occupies bits [11:7] in other formats, and stores have no `rd` (they write to memory, not a register).  Putting immediate bits in the `rd` position keeps the `rs1` and `rs2` fields in the same location across all formats—a critical design decision for fast decode.

### SW: Store Word (4 bytes)

```asm
  sw    rs2, offset(rs1)                         # memory[rs1 + offset] = rs2 (4 bytes)
```

Every peripheral register write uses `sw`:

```asm
  li    t0, UART0_BASE                           # t0 = 0x40070000
  li    t1, 6                                    # t1 = integer baud rate divisor
  sw    t1, UARTIBRD(t0)                         # memory[0x40070024] = 6
```

**Alignment**: effective address must be divisible by 4.

### SH: Store Halfword (2 bytes)

```asm
  sh    rs2, offset(rs1)                         # memory[rs1 + offset] = rs2[15:0]
```

Writes the lower 16 bits of `rs2`.

### SB: Store Byte (1 byte)

```asm
  sb    rs2, offset(rs1)                         # memory[rs1 + offset] = rs2[7:0]
```

Writes the lowest 8 bits of `rs2`.

## Why Our Firmware Uses Only LW and SW

All RP2350 peripheral registers are 32 bits wide and 4-byte aligned.  The data sheet specifies 32-bit register widths throughout.  Therefore:
- We read them with `lw`
- We write them with `sw`

The `lb`/`lh`/`sb`/`sh` variants are useful for manipulating byte or halfword data in RAM (strings, packets), but for peripheral register access, word-size operations are standard.

## Offset Encoding Constraints

The offset in load/store instructions is a 12-bit signed value:
- Range: -2048 to +2047
- This is why we first load base addresses into registers

### Why This Works

Peripheral blocks cluster their registers close together.  UART0 has registers at offsets 0x00-0x30.  RESETS has registers at offsets 0x00-0x0C.  These all fit within the 12-bit offset range.

If we needed to access a register at offset 0x1000 from a base, we would need to adjust:
```asm
  li    t0, SOME_BASE                            # base address
  li    t2, 0x1000                               # large offset
  add   t0, t0, t2                               # new base = old base + 0x1000
  lw    t1, 0x00(t0)                             # now offset is 0
```

In practice, RP2350 peripheral registers never need this because all offsets are small.

## Complete Memory Access Map for Our Firmware

Here is every memory access our firmware makes, organized by peripheral:

### XOSC (Base: 0x40048000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| sw | 0x0C | XOSC_STARTUP | Write 0x00C4 (startup delay) |
| sw | 0x00 | XOSC_CTRL | Write 0x00FABAA0 (enable crystal) |
| lw | 0x04 | XOSC_STATUS | Read and poll bit 31 (stable) |

### CLOCKS (Base: 0x40010000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| lw | 0x48 | CLK_PERI_CTRL | Read current value |
| sw | 0x48 | CLK_PERI_CTRL | Write with bit 11 set (enable) |

### RESETS (Base: 0x40020000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| lw | 0x00 | RESETS_RESET | Read current reset bits |
| sw | 0x00 | RESETS_RESET | Write to clear reset bits |
| lw | 0x08 | RESETS_RESET_DONE | Read to poll completion |

### IO_BANK0 (Base: 0x40028000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| sw | 0x04 | GPIO0_CTRL | Write FUNCSEL=2 (UART TX) |
| sw | 0x0C | GPIO1_CTRL | Write FUNCSEL=2 (UART RX) |

### PADS_BANK0 (Base: 0x40038000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| sw | 0x04 | GPIO0 pad | Write 0x04 (output enable, drive) |
| sw | 0x08 | GPIO1 pad | Write 0x40 (input enable, pull-up) |

### UART0 (Base: 0x40070000)

| Access | Offset | Register | Operation |
|---|---:|---|---|
| sw | 0x30 | UARTCR | Disable UART (write 0) |
| sw | 0x24 | UARTIBRD | Write integer baud divisor (6) |
| sw | 0x28 | UARTFBRD | Write fractional baud divisor (33) |
| sw | 0x2C | UARTLCR_H | Write line control (0x70) |
| sw | 0x30 | UARTCR | Enable UART with TX/RX |
| lw | 0x18 | UARTFR | Read flags (poll TX full, RX empty) |
| sw | 0x00 | UARTDR | Write data byte (transmit) |
| lw | 0x00 | UARTDR | Read data byte (receive) |

## Practice Problems

1. What is the effective address for `lw t1, 0x30(t0)` when t0 = 0x40070000?
2. How many bytes does `sh` write?
3. Loading byte 0x85 with `lb` gives what 32-bit value?  With `lbu`?
4. Why does the S-type format split the immediate across two bit fields?

### Answers

1. 0x40070000 + 0x30 = 0x40070030
2. 2 bytes (halfword)
3. `lb`: 0xFFFFFF85 (sign-extended, bit 7=1).  `lbu`: 0x00000085 (zero-extended)
4. To keep rs1 and rs2 in the same bit positions across all instruction formats, simplifying hardware decode logic.

## Chapter Summary

RISC-V has five load instructions (lw, lh, lhu, lb, lbu) and three store instructions (sw, sh, sb).  All use base+offset addressing with 12-bit signed offsets.  Our firmware uses exclusively lw/sw because RP2350 peripheral registers are 32-bit.  Word accesses must be 4-byte aligned.  The complete memory access map shows every register read and write the firmware performs.
