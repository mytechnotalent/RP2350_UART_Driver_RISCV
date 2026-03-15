# Chapter 11: RISC-V Branch Instructions

## Introduction

Programs need to make decisions.  "If the UART TX FIFO is full, wait.  If not, send the byte."  Branch instructions implement this logic by conditionally changing the program counter.

## How Branches Work

A branch instruction compares two registers and, if the condition is true, adds a signed offset to the PC.  If false, execution continues to the next instruction (PC + 4).

```
  Branch taken:     PC = PC + sign_extend(offset)
  Branch not taken: PC = PC + 4
```

The offset is encoded as a 13-bit signed value (12 bits in B-type, with the LSB always 0 because instructions are at least 2-byte aligned).  This gives a range of ±4 KiB from the branch instruction.

## B-Type Encoding

```
  [imm[12|10:5] | rs2 | rs1 | funct3 | imm[4:1|11] | opcode=1100011]
```

The immediate bits are scrambled across the instruction word.  This is intentional—it keeps the sign bit always at bit 31 and the register fields always in the same position.  The CPU reassembles the immediate during decode.

## The Six Branch Instructions

### BEQ: Branch if Equal

```asm
  beq   rs1, rs2, label                          # if (rs1 == rs2) goto label
```

### BNE: Branch if Not Equal

```asm
  bne   rs1, rs2, label                          # if (rs1 != rs2) goto label
```

### BLT: Branch if Less Than (signed)

```asm
  blt   rs1, rs2, label                          # if (rs1 < rs2) goto label (signed)
```

### BGE: Branch if Greater or Equal (signed)

```asm
  bge   rs1, rs2, label                          # if (rs1 >= rs2) goto label (signed)
```

### BLTU: Branch if Less Than (unsigned)

```asm
  bltu  rs1, rs2, label                          # if (rs1 < rs2) goto label (unsigned)
```

### BGEU: Branch if Greater or Equal (unsigned)

```asm
  bgeu  rs1, rs2, label                          # if (rs1 >= rs2) goto label (unsigned)
```

## Signed vs Unsigned Comparison

This distinction is critical.  Consider comparing 0xFFFFFFFF and 0x00000001:

- **Signed**: 0xFFFFFFFF = -1, 0x00000001 = 1.  So -1 < 1 is TRUE.  `blt` would branch.
- **Unsigned**: 0xFFFFFFFF = 4,294,967,295, 0x00000001 = 1.  So 4B > 1 is TRUE.  `bltu` would NOT branch.

For peripheral register bits (which are always unsigned), use `bltu`/`bgeu` if you need unsigned comparison.  But usually we test individual bits with `andi` + `beqz`/`bnez`.

## Pseudoinstruction Branches

The assembler provides convenient shortcuts by using `zero` as an implicit operand:

| Pseudoinstruction | Expansion | Meaning |
|---|---|---|
| beqz rs1, label | beq rs1, zero, label | Branch if rs1 == 0 |
| bnez rs1, label | bne rs1, zero, label | Branch if rs1 != 0 |
| blez rs1, label | bge zero, rs1, label | Branch if rs1 <= 0 |
| bgez rs1, label | bge rs1, zero, label | Branch if rs1 >= 0 |
| bltz rs1, label | blt rs1, zero, label | Branch if rs1 < 0 |
| bgtz rs1, label | blt zero, rs1, label | Branch if rs1 > 0 |

## Branches in Our Firmware

### Polling the XOSC Status (xosc.s)

The crystal oscillator takes time to stabilize.  We poll the status register:

```asm
.Lwait_xosc:
  lw    t1, XOSC_STATUS(t0)                      # read XOSC status register
  bgez  t1, .Lwait_xosc                          # loop if bit 31 not set (not stable)
```

How this works:
1. `lw` loads the 32-bit status register into `t1`
2. `bgez` checks if `t1 >= 0` (signed comparison)
3. Bit 31 is the sign bit in two's complement
4. If bit 31 = 0, the value is positive/zero → `bgez` branches back (keep waiting)
5. If bit 31 = 1, the value is negative → `bgez` falls through (XOSC is stable)

This is a clever trick: testing the most significant bit using signed comparison avoids needing a separate mask-and-test sequence.

### Polling the Reset Done Register (reset.s)

After clearing a reset bit, we wait for the done bit to assert:

```asm
.Lwait_io:
  lw    t1, RESETS_RESET_DONE(t0)                # read reset done register
  andi  t1, t1, (1 << 6)                         # isolate IO_BANK0 done bit
  beqz  t1, .Lwait_io                            # loop if bit 6 not set (not done)
```

How this works:
1. `lw` loads the reset done status
2. `andi` masks all bits except bit 6
3. If bit 6 = 0: result is 0 → `beqz` branches (keep waiting)
4. If bit 6 = 1: result is 0x40 (non-zero) → `beqz` falls through (done)

### Polling UART TX FIFO (uart.s)

Before transmitting, we check if the TX FIFO is full:

```asm
.Lwait_tx:
  lw    t1, UARTFR(t0)                           # read UART flag register
  andi  t1, t1, UART_TXFF                        # isolate TX FIFO Full flag (bit 5)
  bnez  t1, .Lwait_tx                            # loop if FIFO is full
```

And for receiving, we check if the RX FIFO is empty:

```asm
.Lwait_rx:
  lw    t1, UARTFR(t0)                           # read UART flag register
  andi  t1, t1, UART_RXFE                        # isolate RX FIFO Empty flag (bit 4)
  bnez  t1, .Lwait_rx                            # loop if FIFO is empty
```

### Pattern: Poll Loop

Every polling loop follows the same structure:

```asm
.Lloop:
  lw    tX, OFFSET(base)                         # read hardware status
  andi  tX, tX, MASK                             # isolate bit of interest
  beqz/bnez tX, .Lloop                           # loop or fall through
```

This is the fundamental pattern for busy-waiting on hardware.

## Local Labels

Notice the `.L` prefix on branch targets: `.Lwait_xosc`, `.Lwait_tx`, `.Lwait_io`.  The `.L` prefix marks a label as **local** — it is only visible within the current file and will not appear in the symbol table.  This is a GNU assembler convention.

## Branch Range Limitation

The 13-bit signed offset gives a range of ±4096 bytes from the branch instruction.  For our firmware, all branches are within a few instructions of their target, so this is never an issue.

If you needed to branch farther, you would use a jump instruction (`j label`) which has a 21-bit offset (±1 MiB range), or an indirect jump through a register.

## No Flags Register

A key RISC-V design decision: there are no condition flags (no carry flag, no zero flag, no negative flag, no overflow flag).  Every branch directly compares two registers.

This differs from ARM and x86, where compare instructions set flags and branches check those flags.

Consequences:
- No `cmp` instruction needed (compare is built into the branch)
- No flag-setting side effects from arithmetic
- Simpler out-of-order execution (no flag dependencies)

## Practice Problems

1. What happens when `beq t0, t1, label` executes and t0 = 5, t1 = 5?
2. What is the maximum branch range?
3. How does `bgez t1, label` effectively test bit 31?
4. Rewrite `bnez t1, .Lloop` using base instructions only (no pseudoinstruction).
5. Why does RISC-V have no FLAGS register?

### Answers

1. Branch taken — execution jumps to `label` because t0 == t1.
2. ±4096 bytes (±4 KiB) from the branch instruction.
3. In two's complement, a number is negative if and only if bit 31 = 1.  `bgez` branches if the value is ≥ 0, meaning bit 31 = 0.  If we want to continue when bit 31 is set, `bgez` loops while it is not.
4. `bne t1, zero, .Lloop`
5. To simplify pipeline design — flags create dependencies between instructions that complicate out-of-order execution.

## Chapter Summary

RISC-V has six branch instructions comparing two registers: beq, bne, blt, bge, bltu, bgeu.  Pseudoinstructions like beqz and bnez compare against zero.  Branches have ±4 KiB range.  Our firmware uses branches in poll loops to wait for hardware status bits.  The `bgez` trick tests bit 31 using signed comparison.  RISC-V has no flags register — every branch encodes its own comparison.
