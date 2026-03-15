# Chapter 8: RISC-V Immediate and Upper-Immediate Instructions

## Introduction

Many instructions need constant values: addresses, bit masks, shift amounts, offsets.  RISC-V provides several ways to work with constants (called "immediates") that are encoded directly within the instruction word.  This chapter covers every immediate-related instruction you will see in our firmware.

## What Is an Immediate?

An immediate is a constant value embedded inside the instruction encoding.  When the CPU decodes the instruction, it extracts this value and uses it as an operand instead of reading a register.

```asm
  addi  t0, zero, 42                             # t0 = 0 + 42 = 42
```

Here, `42` is the immediate.  It is part of the binary instruction word itself.  No memory access is needed to get this value.

## I-Type Immediates (12-bit Signed)

I-type instructions embed a 12-bit signed immediate, giving a range of -2048 to +2047.

### ADDI: Add Immediate

```
  addi  rd, rs1, imm                             # rd = rs1 + sign_extend(imm)
```

Used everywhere.  Examples from our firmware:

```asm
  addi  t0, t0, 1                                # increment t0 by 1
  addi  sp, sp, -16                              # allocate 16 bytes on stack
  addi  sp, sp, 16                               # deallocate 16 bytes on stack
```

### ANDI: AND Immediate

```
  andi  rd, rs1, imm                             # rd = rs1 & sign_extend(imm)
```

Used to mask bits.  From our UART code:

```asm
  andi  t1, t1, UART_TXFF                        # isolate TX FIFO full bit
```

### ORI: OR Immediate

```
  ori   rd, rs1, imm                             # rd = rs1 | sign_extend(imm)
```

Used to set specific bits while preserving others.

### XORI: XOR Immediate

```
  xori  rd, rs1, imm                             # rd = rs1 ^ sign_extend(imm)
```

Special case: `xori rd, rs1, -1` flips all bits (bitwise NOT).  The assembler pseudoinstruction `not rd, rs1` expands to this.

### SLTI: Set Less Than Immediate

```
  slti  rd, rs1, imm                             # rd = (rs1 < sign_extend(imm)) ? 1 : 0
```

Signed comparison.  Sets `rd` to 1 if `rs1` is less than the immediate.

### SLTIU: Set Less Than Immediate Unsigned

```
  sltiu rd, rs1, imm                             # rd = (rs1 <u sign_extend(imm)) ? 1 : 0
```

Special case: `sltiu rd, rs1, 1` sets `rd` to 1 if `rs1` is zero (used by `seqz` pseudoinstruction).

## Shift Immediates

Shift amounts are 5-bit unsigned values (0-31) encoded in the I-type immediate field:

```asm
  slli  rd, rs1, shamt                           # rd = rs1 << shamt (logical left)
  srli  rd, rs1, shamt                           # rd = rs1 >> shamt (logical right)
  srai  rd, rs1, shamt                           # rd = rs1 >> shamt (arithmetic right)
```

**Logical shift right** (`srli`): fills with zeros from the left
**Arithmetic shift right** (`srai`): fills with copies of the sign bit (preserves sign)

Example:
```
  Value: 0xFF000000 = 1111 1111 0000 0000 0000 0000 0000 0000

  srli rd, rs1, 8:   0x00FF0000  (zeros fill from left)
  srai rd, rs1, 8:   0xFFFF0000  (sign bit fills from left)
```

## U-Type Instructions: LUI and AUIPC

The 12-bit immediate limit is a problem.  Addresses like `0x40070000` do not fit in 12 bits.  U-type instructions solve this.

### LUI: Load Upper Immediate

```
  lui   rd, imm20                                # rd = imm20 << 12
```

LUI takes a 20-bit immediate and places it in the upper 20 bits of `rd`, zeroing the lower 12 bits.

```asm
  lui   t0, 0x40070                              # t0 = 0x40070000
```

Result bit pattern:
```
  [0100 0000 0000 0111 0000] [0000 0000 0000]
   ^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^
   upper 20 bits from imm     lower 12 bits = 0
```

### AUIPC: Add Upper Immediate to PC

```
  auipc rd, imm20                                # rd = PC + (imm20 << 12)
```

Like LUI but adds to the current PC instead of starting from zero.  Used for PC-relative addressing.  The `call` pseudoinstruction uses this.

## Building 32-bit Constants: LUI + ADDI

To load any 32-bit constant, combine LUI (sets upper 20 bits) with ADDI (sets lower 12 bits):

```asm
  lui   t0, 0x20082                              # t0 = 0x20082000
  addi  t0, t0, 0x000                            # t0 = 0x20082000 + 0x000 = 0x20082000
```

Another example:
```asm
  lui   t0, 0x40070                              # t0 = 0x40070000
  addi  t0, t0, 0x000                            # t0 = 0x40070000
```

### The Sign-Extension Trap

ADDI sign-extends its 12-bit immediate.  If bit 11 is set (values 0x800 to 0xFFF), the immediate becomes negative.  The assembler compensates by adding 1 to the LUI value.

Example: Load `0x20082800`
```
  Lower 12 bits: 0x800 → sign extends to 0xFFFFF800 (negative!)
  
  Naïve:  lui t0, 0x20082;  addi t0, t0, 0x800
  Result: 0x20082000 + 0xFFFFF800 = 0x20081800  WRONG!
  
  Correct: lui t0, 0x20083;  addi t0, t0, -0x800
  Result:  0x20083000 + 0xFFFFF800 = 0x20082800  CORRECT!
```

Fortunately, the `li` pseudoinstruction handles this automatically.  You write:
```asm
  li    t0, 0x20082800                           # assembler generates correct lui+addi
```

## The LI Pseudoinstruction

`li` (load immediate) is not a real RISC-V instruction.  It is a pseudoinstruction that the assembler expands into one or two real instructions:

| Value Range | Expansion |
|---|---|
| -2048 to +2047 | `addi rd, zero, imm` (single instruction) |
| Upper bits only | `lui rd, imm20` (single instruction) |
| General 32-bit | `lui rd, upper20` then `addi rd, rd, lower12` |

Examples:
```asm
  li    t0, 42                                   # becomes: addi t0, zero, 42
  li    t0, 0x40070000                           # becomes: lui t0, 0x40070
  li    sp, 0x20082000                           # becomes: lui sp, 0x20082
  li    t0, 0x00FABAA0                           # becomes: lui t0, 0x00FAB; addi t0, t0, -0x560
```

That last example shows the sign-extension compensation at work.  0xAA0 has bit 11 set, so the assembler adjusts.

## LA: Load Address

`la` (load address) loads the address of a symbol:

```asm
  la    t0, Default_Trap_Handler                 # t0 = address of handler
```

For position-dependent code (which our firmware uses), this expands similarly to `li` but with the symbol's address.  For position-independent code, it uses `auipc` + `addi`.

From our `reset_handler.s`:
```asm
  la    t0, Default_Trap_Handler                 # load handler address into t0
  csrw  mtvec, t0                                # write to trap vector CSR
```

## Practice Problems

1. What is the range of a 12-bit signed immediate?
2. `lui t0, 0x12345` — what value ends up in t0?
3. Why can't `addi t0, zero, 0x40070000` work?
4. How many real instructions does `li t0, 1` generate?
5. What does `xori t0, t0, -1` do?

### Answers

1. -2048 to +2047
2. 0x12345000 (upper 20 bits set, lower 12 zeroed)
3. 0x40070000 does not fit in 12 bits.  ADDI only has a 12-bit immediate field.
4. One: `addi t0, zero, 1` (value fits in 12-bit immediate)
5. Flips all bits in t0 (bitwise NOT).  -1 = 0xFFFFFFFF, XOR with all-ones inverts every bit.

## Chapter Summary

Immediates are constants embedded in instructions.  I-type instructions have 12-bit signed immediates (-2048 to +2047).  LUI loads 20 upper bits.  LUI + ADDI together build any 32-bit constant.  The `li` pseudoinstruction handles this automatically; including the sign-extension adjustment.  AUIPC enables PC-relative addressing.  `la` loads symbol addresses.
