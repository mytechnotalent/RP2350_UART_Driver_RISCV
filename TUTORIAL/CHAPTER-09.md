# Chapter 9: RISC-V Arithmetic and Logic Instructions

## Introduction

These are the instructions that do the actual computation.  Every bit manipulation, every mask test, every address calculation in our firmware comes down to these register-to-register operations.

## R-Type Format Recap

All register arithmetic uses R-type encoding:

```
  [funct7 | rs2 | rs1 | funct3 | rd | opcode]
```

Two source registers (rs1, rs2) and one destination register (rd).

## Addition and Subtraction

### ADD

```asm
  add   rd, rs1, rs2                             # rd = rs1 + rs2
```

32-bit addition.  Overflow wraps silently (no exception, no flag).

### SUB

```asm
  sub   rd, rs1, rs2                             # rd = rs1 - rs2
```

32-bit subtraction.

### ADDI (review)

```asm
  addi  rd, rs1, imm                             # rd = rs1 + sign_extend(imm)
```

There is no `subi` instruction.  To subtract an immediate, use `addi` with a negative value:
```asm
  addi  sp, sp, -16                              # sp = sp - 16
```

## Logical Operations

These operate on individual bits.  Each bit in the result depends only on the corresponding bits of the operands.

### AND

```asm
  and   rd, rs1, rs2                             # rd = rs1 & rs2
  andi  rd, rs1, imm                             # rd = rs1 & sign_extend(imm)
```

Truth table:
```
  A | B | A AND B
  0 | 0 |   0
  0 | 1 |   0
  1 | 0 |   0
  1 | 1 |   1
```

**Use case: testing a bit** — AND with a mask that has only the target bit set:
```asm
  andi  t1, t1, (1 << 5)                         # isolate bit 5, all others become 0
```

If bit 5 was 1, result is 0x20 (non-zero).  If bit 5 was 0, result is 0.

**Use case: clearing bits** — AND with mask where target bits are 0:
```asm
  li    t2, ~(1 << 6)                            # t2 = 0xFFFFFFBF (bit 6 clear)
  and   t1, t1, t2                               # clear bit 6 of t1
```

### OR

```asm
  or    rd, rs1, rs2                             # rd = rs1 | rs2
  ori   rd, rs1, imm                             # rd = rs1 | sign_extend(imm)
```

Truth table:
```
  A | B | A OR B
  0 | 0 |   0
  0 | 1 |   1
  1 | 0 |   1
  1 | 1 |   1
```

**Use case: setting a bit** — OR with a mask that has the target bit set:
```asm
  ori   t1, t1, (1 << 11)                        # set bit 11 of t1
```

### XOR

```asm
  xor   rd, rs1, rs2                             # rd = rs1 ^ rs2
  xori  rd, rs1, imm                             # rd = rs1 ^ sign_extend(imm)
```

Truth table:
```
  A | B | A XOR B
  0 | 0 |   0
  0 | 1 |   1
  1 | 0 |   1
  1 | 1 |   0
```

**Use case: toggling a bit** — XOR with a mask:
```asm
  xori  t1, t1, (1 << 3)                         # toggle bit 3 of t1
```

**Use case: bitwise NOT** — XOR with all ones:
```asm
  xori  t1, t1, -1                               # t1 = ~t1 (flip all bits)
```

## Shift Operations

Shifts move bits left or right within a register.

### SLL: Shift Left Logical

```asm
  sll   rd, rs1, rs2                             # rd = rs1 << rs2[4:0]
  slli  rd, rs1, shamt                           # rd = rs1 << shamt
```

Bits shift left, zeros fill from the right.

```
  Before: 0000 0000 0000 0000 0000 0000 0000 0001  (value 1)
  slli by 5:
  After:  0000 0000 0000 0000 0000 0000 0010 0000  (value 32)
```

This is equivalent to multiplying by 2ⁿ.  `slli rd, rs1, 1` doubles the value.

**Use case: creating bit masks**:
```asm
  li    t0, 1                                    # t0 = 1
  slli  t0, t0, 26                               # t0 = (1 << 26) = 0x04000000
```

### SRL: Shift Right Logical

```asm
  srl   rd, rs1, rs2                             # rd = rs1 >> rs2[4:0] (zero fill)
  srli  rd, rs1, shamt                           # rd = rs1 >> shamt (zero fill)
```

Bits shift right, zeros fill from the left.

```
  Before: 1000 0000 0000 0000 0000 0000 0000 0000  (0x80000000)
  srli by 4:
  After:  0000 1000 0000 0000 0000 0000 0000 0000  (0x08000000)
```

### SRA: Shift Right Arithmetic

```asm
  sra   rd, rs1, rs2                             # rd = rs1 >> rs2[4:0] (sign fill)
  srai  rd, rs1, shamt                           # rd = rs1 >> shamt (sign fill)
```

Bits shift right, but the sign bit (bit 31) is replicated to fill:

```
  Before: 1000 0000 0000 0000 0000 0000 0000 0000  (0x80000000, negative)
  srai by 4:
  After:  1111 1000 0000 0000 0000 0000 0000 0000  (0xF8000000, still negative)
```

This preserves the sign during division by powers of 2.

## Comparison Instructions

### SLT: Set Less Than

```asm
  slt   rd, rs1, rs2                             # rd = (rs1 < rs2) ? 1 : 0 (signed)
  sltu  rd, rs1, rs2                             # rd = (rs1 < rs2) ? 1 : 0 (unsigned)
```

These are the only "compare and set" instructions in RV32I.  They set the destination to 1 or 0.

The `sltu rd, zero, rs2` pattern sets `rd` to 1 if `rs2` is non-zero.  The pseudoinstruction `snez rd, rs1` uses this.

## MUL from M Extension

Our firmware uses multiply in `delay.s`:

```asm
  li    t0, 3600                                 # loops per millisecond at ~14.5 MHz
  mul   t1, a0, t0                               # t1 = a0 × 3600
```

`mul rd, rs1, rs2` produces the lower 32 bits of the full 64-bit product.  For most embedded work, this is all you need.

## Read-Modify-Write Pattern

The most common pattern in peripheral programming combines loads, bitwise operations, and stores.  Here is how we clear a bit in a peripheral register:

```asm
  li    t0, RESETS_BASE                          # t0 = 0x40020000
  lw    t1, RESETS_RESET(t0)                     # t1 = current register value
  li    t2, (1 << 6)                             # t2 = bit mask for IO_BANK0
  not   t2, t2                                   # t2 = ~(1 << 6) = 0xFFFFFFBF
  and   t1, t1, t2                               # clear bit 6, preserve all others
  sw    t1, RESETS_RESET(t0)                     # write back modified value
```

Step by step:
1. **Load** the current register value into a register
2. **Modify** using AND/OR/XOR to change specific bits
3. **Write** the modified value back

This is called read-modify-write (RMW) and you will see it repeatedly in our peripheral initialization code.

## Practice Problems

1. What is the result of `andi t0, t0, 0xFF` when t0 = 0x12345678?
2. What instruction creates a bit mask with bit 11 set?
3. If t0 = 0x80000000, what is the result of `srli t0, t0, 1`?  What about `srai t0, t0, 1`?
4. How do you clear bit 26 of register t1 without affecting other bits?
5. Why is there no `subi` instruction?

### Answers

1. 0x00000078 (only lowest 8 bits survive the mask)
2. `li t0, 1; slli t0, t0, 11` → t0 = 0x00000800
3. `srli`: 0x40000000 (zero fills from left).  `srai`: 0xC0000000 (sign bit fills)
4. `li t2, (1 << 26); not t2, t2; and t1, t1, t2` — or load ~(1<<26) directly
5. Because `addi rd, rs1, -N` accomplishes the same thing.  Removing subi simplifies hardware.

## Chapter Summary

R-type instructions perform register-to-register arithmetic and logic.  AND masks/tests bits.  OR sets bits.  XOR toggles bits or inverts.  Shifts move bits left or right.  The read-modify-write pattern combines load, bitwise logic, and store to change specific bits in peripheral registers.  These instructions are the building blocks of all hardware control in bare-metal programming.
