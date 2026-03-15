# Chapter 7: RISC-V ISA Overview

## Introduction

An Instruction Set Architecture (ISA) defines the contract between software and hardware.  It specifies what instructions the CPU understands, what registers are available, how memory is accessed, and how the CPU responds to exceptions.

RISC-V is a modular ISA.  The base is small and simple.  Extensions add functionality.  This chapter surveys the complete ISA configuration used on the RP2350 Hazard3 core.

## The RISC-V Design Philosophy

RISC-V follows these principles:

1. **Simplicity**: few instruction formats, regular encoding, orthogonal design
2. **Modularity**: start with base integer ISA, add extensions as needed
3. **Load-store**: only load/store instructions access memory
4. **Fixed register file**: 32 registers, x0 hardwired to zero
5. **No condition codes**: branches compare registers directly (no FLAGS register)
6. **Open standard**: freely available specification, no licensing fees

## Our ISA String: rv32imac_zicsr

Each letter represents an extension.  Let us decode them one by one.

### RV32I — Base Integer ISA

This is the foundation.  Every RISC-V processor must implement this.

The RV32I base provides:
- 32 general-purpose registers (x0-x31), each 32 bits
- Program counter (pc)
- Integer arithmetic: add, sub, and, or, xor, sll, srl, sra, slt, sltu
- Immediate variants: addi, andi, ori, xori, slli, srli, srai, slti, sltiu
- Load/store: lb, lbu, lh, lhu, lw, sb, sh, sw
- Branches: beq, bne, blt, bge, bltu, bgeu
- Jumps: jal, jalr
- Upper immediate: lui, auipc
- System: ecall, ebreak
- Fence: fence (memory ordering)

That is the complete base.  47 instructions.  Everything else is an extension.

### M — Multiply/Divide Extension

Adds hardware multiply and divide:

| Instruction | Operation |
|---|---|
| mul rd, rs1, rs2 | rd = (rs1 × rs2)[31:0] |
| mulh rd, rs1, rs2 | rd = (rs1 × rs2)[63:32] (signed) |
| mulhsu rd, rs1, rs2 | rd = (rs1 × rs2)[63:32] (signed × unsigned) |
| mulhu rd, rs1, rs2 | rd = (rs1 × rs2)[63:32] (unsigned) |
| div rd, rs1, rs2 | rd = rs1 ÷ rs2 (signed) |
| divu rd, rs1, rs2 | rd = rs1 ÷ rs2 (unsigned) |
| rem rd, rs1, rs2 | rd = rs1 mod rs2 (signed) |
| remu rd, rs1, rs2 | rd = rs1 mod rs2 (unsigned) |

Our firmware uses `mul` in `delay.s` to compute loop counts:

```asm
  li    t0, 3600                                 # loops per millisecond
  mul   t1, a0, t0                               # total loops = ms × 3600
```

Without the M extension, you would need a software multiplication loop.

### A — Atomic Extension

Adds atomic memory operations for multiprocessor synchronization:

| Instruction | Operation |
|---|---|
| lr.w rd, (rs1) | Load-reserved word |
| sc.w rd, rs2, (rs1) | Store-conditional word |
| amoswap.w | Atomic swap |
| amoadd.w | Atomic add |
| amoand.w | Atomic AND |
| amoor.w | Atomic OR |
| amoxor.w | Atomic XOR |
| amomin.w | Atomic minimum |
| amomax.w | Atomic maximum |

Our firmware does not use atomic operations (we run single-threaded on one core), but the Hazard3 core implements them.

### C — Compressed Extension

The C extension adds 16-bit versions of common instructions.  This reduces code size by roughly 25-30%.

Examples:
- `c.lw` — compressed load word (16-bit encoding instead of 32-bit)
- `c.sw` — compressed store word
- `c.addi` — compressed add immediate
- `c.j` — compressed jump
- `c.beqz` — compressed branch if zero

The assembler automatically selects compressed encodings when possible.  You write normal instructions and the assembler compresses them.

The CPU identifies compressed instructions by checking the lowest 2 bits:
- If bits [1:0] ≠ 11, it is a 16-bit compressed instruction
- If bits [1:0] = 11, it is a 32-bit instruction

This is why RISC-V instructions with the C extension must be aligned to 2 bytes (not 4).

### Zicsr — Control and Status Register Extension

This adds instructions to read and write Control and Status Registers (CSRs).  CSRs are special registers that control processor behavior.

| Instruction | Operation |
|---|---|
| csrr rd, csr | Read CSR into rd (pseudoinstruction) |
| csrw csr, rs1 | Write rs1 into CSR (pseudoinstruction) |
| csrrw rd, csr, rs1 | Atomic read/write CSR |
| csrrs rd, csr, rs1 | Atomic read and set bits |
| csrrc rd, csr, rs1 | Atomic read and clear bits |
| csrrwi rd, csr, imm | CSR read/write with immediate |
| csrrsi rd, csr, imm | CSR set bits with immediate |
| csrrci rd, csr, imm | CSR clear bits with immediate |

Our firmware uses CSR instructions in `reset_handler.s`:

```asm
  csrw  mtvec, t0                                # set machine trap vector base
```

This writes the address of our trap handler into the `mtvec` CSR, telling the CPU where to jump when an exception or interrupt occurs.

Key CSRs on RP2350 Hazard3:
| CSR | Name | Purpose |
|---|---|---|
| mstatus | Machine status | Global interrupt enable, privilege mode |
| mtvec | Machine trap vector | Trap handler address |
| mepc | Machine exception PC | PC at time of exception |
| mcause | Machine cause | Exception cause code |

## Instruction Encoding Summary

All RISC-V instructions (non-compressed) are exactly 32 bits.  Six formats:

| Format | Used For | Key Feature |
|---|---|---|
| R-type | Register arithmetic | Two source registers, one destination |
| I-type | Immediates, loads, jalr | 12-bit immediate |
| S-type | Stores | 12-bit immediate (split) |
| B-type | Branches | 12-bit branch offset (split) |
| U-type | lui, auipc | 20-bit upper immediate |
| J-type | jal | 20-bit jump offset |

The opcode is ALWAYS in bits [6:0].  This makes decode fast and uniform.

## How This Maps to Our Firmware

Every instruction in our firmware uses one of these formats:

```asm
  li    t0, 0x40070000                           # lui + addi  (U-type + I-type)
  lw    t1, 0x18(t0)                             # I-type load
  sw    a0, 0x00(t0)                             # S-type store
  andi  t1, t1, 0x20                             # I-type immediate
  bnez  t1, .Lwait                               # B-type branch
  call  Init_Stack                               # auipc + jalr (U-type + I-type)
  ret                                            # jalr zero, ra, 0 (I-type)
  j     .Loop                                    # jal zero, offset (J-type)
```

## Chapter Summary

Our ISA is rv32imac_zicsr: 32-bit base integers, multiply/divide, atomics, compressed instructions, and CSR access.  The base RV32I has 47 instructions.  Each extension adds capability without changing the base.  All instructions are either 32 bits (normal) or 16 bits (compressed).  The modular design keeps hardware simple while providing exactly the features needed.
