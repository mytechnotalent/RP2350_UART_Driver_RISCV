# Chapter 13: Pseudoinstructions — What the Assembler Does For You

## Introduction

RISC-V keeps its instruction set minimal.  But writing raw machine instructions for every operation would be tedious.  The assembler provides **pseudoinstructions**: convenient mnemonics that expand into one or more real instructions.  This chapter catalogs every pseudoinstruction used in our firmware.

## What Is a Pseudoinstruction?

A pseudoinstruction is an assembly mnemonic that does NOT correspond to a single hardware instruction.  The assembler translates it into one or more real instructions before generating machine code.

You write:
```asm
  li    t0, 0x40070000                           # load immediate
```

The assembler generates:
```asm
  lui   t0, 0x40070                              # real instruction: upper 20 bits
  addi  t0, t0, 0x000                            # real instruction: lower 12 bits
```

Both LUI and ADDI are real hardware instructions.  LI is the pseudoinstruction.

## Complete Pseudoinstruction Reference

### LI: Load Immediate

```asm
  li    rd, immediate                            # rd = immediate (any 32-bit value)
```

| Immediate Range | Expansion |
|---|---|
| -2048 to +2047 | `addi rd, zero, imm` |
| Upper 20 bits only, lower 12 = 0 | `lui rd, imm20` |
| General 32-bit | `lui rd, upper20` + `addi rd, rd, lower12` |

Used extensively throughout our firmware:
```asm
  li    sp, STACK_TOP                            # sp = 0x20082000 (stack.s)
  li    t0, UART0_BASE                           # t0 = 0x40070000 (uart.s)
  li    t1, 6                                    # t1 = 6 (baud rate divisor)
  li    t1, 0x00FABAA0                           # t1 = XOSC enable value (xosc.s)
```

### LA: Load Address

```asm
  la    rd, symbol                               # rd = address of symbol
```

For absolute addressing (our firmware), expands like `li` with the symbol's resolved address.  For PIC (position-independent code), uses `auipc` + `addi`.

Used in our firmware:
```asm
  la    t0, Default_Trap_Handler                 # load trap handler address (reset_handler.s)
```

### MV: Move Register

```asm
  mv    rd, rs1                                  # rd = rs1
```

Expands to:
```asm
  addi  rd, rs1, 0                               # add zero to source
```

### NOT: Bitwise NOT

```asm
  not   rd, rs1                                  # rd = ~rs1 (flip all bits)
```

Expands to:
```asm
  xori  rd, rs1, -1                              # XOR with all ones
```

Used in our firmware for read-modify-write:
```asm
  not   t2, t2                                   # invert mask for clearing bits
```

### NEG: Negate

```asm
  neg   rd, rs1                                  # rd = -rs1
```

Expands to:
```asm
  sub   rd, zero, rs1                            # subtract from zero
```

### SEQZ: Set if Equal to Zero

```asm
  seqz  rd, rs1                                  # rd = (rs1 == 0) ? 1 : 0
```

Expands to:
```asm
  sltiu rd, rs1, 1                               # rs1 < 1 (unsigned) is true only if rs1 == 0
```

### SNEZ: Set if Not Equal to Zero

```asm
  snez  rd, rs1                                  # rd = (rs1 != 0) ? 1 : 0
```

Expands to:
```asm
  sltu  rd, zero, rs1                            # 0 < rs1 (unsigned) is true if rs1 != 0
```

### NOP: No Operation

```asm
  nop                                            # do nothing
```

Expands to:
```asm
  addi  zero, zero, 0                            # add 0 to x0, result discarded
```

### Branch Pseudoinstructions (Review)

| Pseudo | Expansion |
|---|---|
| beqz rs, label | beq rs, zero, label |
| bnez rs, label | bne rs, zero, label |
| blez rs, label | bge zero, rs, label |
| bgez rs, label | bge rs, zero, label |
| bltz rs, label | blt rs, zero, label |
| bgtz rs, label | blt zero, rs, label |

### Jump and Call Pseudoinstructions (Review)

| Pseudo | Expansion |
|---|---|
| j label | jal zero, label |
| call label | auipc ra, hi20; jalr ra, ra, lo12 |
| ret | jalr zero, ra, 0 |
| tail label | auipc t1, hi20; jalr zero, t1, lo12 |

### CSR Pseudoinstructions

| Pseudo | Expansion |
|---|---|
| csrr rd, csr | csrrs rd, csr, zero |
| csrw csr, rs | csrrw zero, csr, rs |
| csrs csr, rs | csrrs zero, csr, rs |
| csrc csr, rs | csrrc zero, csr, rs |

Used in our firmware:
```asm
  csrw  mtvec, t0                                # write trap vector (reset_handler.s)
```

Expands to:
```asm
  csrrw zero, mtvec, t0                          # atomic read-write, discard old value
```

## Why Pseudoinstructions Matter

1. **Readability**: `li t0, 0x40070000` is clearer than `lui t0, 0x40070; addi t0, t0, 0`
2. **Correctness**: the assembler handles sign-extension compensation automatically
3. **Portability**: pseudoinstructions work across different RISC-V implementations
4. **Flexibility**: `li` automatically chooses the minimal instruction count

## How to Tell if Something Is a Pseudoinstruction

If you look at the RISC-V ISA manual, real instructions are listed with their bit encoding.  Pseudoinstructions are listed in a separate table with their expansions.  If there is no bit encoding, it is a pseudo.

In `objdump` output, you will see the real instructions, not the pseudoinstructions:
```
10000080: 40070537     lui   t0, 0x40070
10000084: 00050513     addi  t0, t0, 0
```

Even though you wrote `li t0, UART0_BASE`.

## Practice Problems

1. How many real instructions does `li t0, 42` generate?
2. What real instruction does `ret` become?
3. What real instruction does `not t1, t1` become?
4. Why is there no `subi` pseudoinstruction needed?
5. What does `mv a0, t0` expand to?

### Answers

1. One: `addi t0, zero, 42` (42 fits in 12-bit immediate)
2. `jalr zero, ra, 0`
3. `xori t1, t1, -1`
4. Because `addi` with a negative immediate already accomplishes subtraction.
5. `addi a0, t0, 0`

## Chapter Summary

Pseudoinstructions are assembler conveniences that expand into real machine instructions.  The most important ones are `li` (load any constant), `la` (load address), `mv` (copy register), `not` (bitwise invert), `call` (function call), `ret` (function return), and `j` (unconditional jump).  Understanding the expansion helps you read disassembly output and debug at the machine level.
