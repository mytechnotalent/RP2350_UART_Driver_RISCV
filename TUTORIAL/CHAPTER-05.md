# Chapter 5: Load-Store Architecture — How RISC-V Accesses Memory

## Introduction

The previous chapter stated that all computation happens in registers and memory is only for loading and storing.  This chapter goes deep into exactly how that works, why RISC-V was designed this way, and how every memory access in our firmware follows this pattern.

## The Load-Store Principle

In a load-store architecture, there are only two ways to interact with memory:

1. **Load**: copy data FROM memory INTO a register
2. **Store**: copy data FROM a register INTO memory

Arithmetic, logic, and comparison instructions **never** touch memory.  They only operate on registers.

```
  ┌──────────────┐                    ┌──────────┐
  │   MEMORY     │  ──── LOAD ────►   │ REGISTER │
  │  (slow)      │  ◄─── STORE ───    │  (fast)  │
  └──────────────┘                    └──────────┘
                                           │
                                      COMPUTE HERE
                                      (add, sub, and,
                                       or, shift, etc.)
```

## Why Load-Store?

This design simplifies the CPU hardware enormously:
- Every instruction does ONE thing: either a memory access OR a computation, never both
- The instruction decoder is simpler because it has fewer cases to handle
- The pipeline (overlapping fetch/decode/execute) is more efficient
- Timing is predictable: load/store take memory-access time, compute takes ALU time

## RISC-V Load Instructions

RISC-V provides loads of different sizes:

| Instruction | Meaning | Bytes Loaded | Sign Extended? |
|---|---|---:|---|
| lb rd, offset(rs1) | Load byte | 1 | Yes |
| lbu rd, offset(rs1) | Load byte unsigned | 1 | No (zero extended) |
| lh rd, offset(rs1) | Load halfword | 2 | Yes |
| lhu rd, offset(rs1) | Load halfword unsigned | 2 | No (zero extended) |
| lw rd, offset(rs1) | Load word | 4 | N/A (fills register) |

Format: `lw rd, offset(rs1)`
- `rd` = destination register (where data goes)
- `rs1` = base register (holds base address)
- `offset` = 12-bit signed immediate (-2048 to +2047)

The effective address is: `rs1 + sign_extend(offset)`

### Sign Extension vs Zero Extension

When you load a single byte into a 32-bit register, the upper 24 bits must be filled with something:
- **Sign extension** (`lb`): copies bit 7 (the sign bit) into bits 8-31.  So 0xFF (−1 as signed byte) becomes 0xFFFFFFFF (−1 as signed word).
- **Zero extension** (`lbu`): fills bits 8-31 with zeros.  So 0xFF becomes 0x000000FF (255).

For hardware register access, we almost always use `lw` because peripheral registers are 32 bits wide.

## RISC-V Store Instructions

| Instruction | Meaning | Bytes Stored |
|---|---|---:|
| sb rs2, offset(rs1) | Store byte | 1 |
| sh rs2, offset(rs1) | Store halfword | 2 |
| sw rs2, offset(rs1) | Store word | 4 |

Format: `sw rs2, offset(rs1)`
- `rs2` = source register (data to write)
- `rs1` = base register (holds base address)
- `offset` = 12-bit signed immediate (-2048 to +2047)

The effective address is: `rs1 + sign_extend(offset)`

**Note the asymmetry**: in loads, the destination register comes first.  In stores, the source register comes first.  This is consistent RISC-V convention but can confuse beginners.

## Walking Through a Real Example

Here is the complete flow for transmitting a character via UART.  This is from `uart.s`:

### Step 1: Load the base address into a register

```asm
  li    t0, UART0_BASE                           # t0 = 0x40070000
```

After: `t0 = 0x40070000`

### Step 2: Load the flag register to check if TX FIFO is full

```asm
  lw    t1, UARTFR(t0)                           # t1 = memory[0x40070018]
```

This computes address = `t0 + 0x18 = 0x40070018` and reads 4 bytes into `t1`.  The hardware responds with the current state of the UART flags.

### Step 3: Test a specific bit

```asm
  andi  t1, t1, UART_TXFF                        # isolate bit 5
```

This is a register-only operation.  It masks `t1` with the value `(1<<5)` = `0x20` = `0b00100000`.  If bit 5 was set (TX FIFO full), the result is non-zero.

### Step 4: Branch based on the result

```asm
  bnez  t1, .Lwait_tx                            # if full, loop back
```

Still register-only.  Compares `t1` to zero and jumps if not equal.

### Step 5: Store the character to transmit

```asm
  sw    a0, UARTDR(t0)                           # memory[0x40070000] = a0
```

This computes address = `t0 + 0x00 = 0x40070000` and writes the value in `a0` to that address.  The UART hardware intercepts this write and begins transmitting the byte.

### Summary of Flow

```
  LOAD (address to register)    → li  t0, base
  LOAD (memory to register)     → lw  t1, offset(t0)    READ FROM HARDWARE
  COMPUTE (register to register)→ andi t1, t1, mask
  BRANCH (register to PC)       → bnez t1, label
  STORE (register to memory)    → sw  a0, offset(t0)    WRITE TO HARDWARE
```

Every single step follows the load-store principle.  Never does the CPU compute on memory directly.

## Base + Offset Addressing

All RISC-V memory instructions use base + offset addressing:

```
  effective_address = register_value + immediate_offset
```

The offset is a 12-bit signed immediate, meaning it ranges from -2048 to +2047.  This is why we load the peripheral base address into a register first: the base is a large 32-bit value like `0x40070000`, but the offsets to individual registers within that peripheral (0x00, 0x04, 0x18, 0x24, etc.) are small and fit in 12 bits.

```asm
  li    t0, 0x40070000                           # base address (needs lui+addi)
  lw    t1, 0x00(t0)                             # UARTDR at base + 0
  lw    t2, 0x18(t0)                             # UARTFR at base + 24
  lw    t3, 0x24(t0)                             # UARTIBRD at base + 36
  lw    t4, 0x28(t0)                             # UARTFBRD at base + 40
  lw    t5, 0x2C(t0)                             # UARTLCR_H at base + 44
  lw    t6, 0x30(t0)                             # UARTCR at base + 48
```

One base register serves all the registers within that peripheral.  This is efficient.

## The Memory Bus

When the CPU executes a load or store, it drives signals on the memory bus:
1. **Address bus**: the 32-bit address to read/write
2. **Data bus**: the 32-bit data being transferred
3. **Control signals**: read vs write, data size, etc.

The bus fabric routes the access to the appropriate target based on the address:
- `0x10xxxxxx` → Flash memory controller
- `0x20xxxxxx` → SRAM controller
- `0x40xxxxxx` → APB peripheral bus
- `0xE0xxxxxx` → Private peripheral bus

This is how "memory-mapped I/O" works: the same load/store instructions used for RAM also work for peripheral registers because the bus fabric routes based on address.

## Practice Problems

1. Given `t0 = 0x40020000`, what address does `lw t1, 0x08(t0)` access?
2. What is the difference between `lb` and `lbu` when loading value 0xFF?
3. In `sw a0, 0x00(t0)`, which register holds the data and which holds the address?
4. Why can't you write `add a0, 0x18(t0)` in RISC-V?

### Answers

1. `0x40020000 + 0x08 = 0x40020008`
2. `lb` sign-extends: 0xFF → 0xFFFFFFFF (−1).  `lbu` zero-extends: 0xFF → 0x000000FF (255).
3. `a0` holds the data (source), `t0` holds the base address.
4. Because `add` is a register-only instruction.  In load-store architecture, you cannot add memory directly.  You must load first, then add.

## Chapter Summary

RISC-V is a load-store architecture.  Only `lw`/`sw` (and their byte/halfword variants) access memory.  All other instructions operate on registers only.  Memory addresses are computed as base register + 12-bit signed offset.  The bus fabric routes loads and stores to the correct hardware based on the address.  This is how memory-mapped I/O works.
