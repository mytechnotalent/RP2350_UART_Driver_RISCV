# Chapter 4: What Is a Register?

## Introduction

A register is a tiny, ultra-fast storage cell inside the CPU.  When the CPU needs to work on data, it loads that data from memory into a register, operates on it, and then stores the result back to memory.  This chapter explains what registers are, why they exist, and how they relate to every instruction you will ever write.

## Why Registers?

Memory access is slow relative to the CPU clock.  Even SRAM takes multiple clock cycles to access.  Registers are built directly into the CPU's silicon and can be read or written in a single cycle.

The design principle of RISC-V (and all RISC architectures) is:

> **All computation happens in registers.  Memory is only for loading and storing.**

This is called the **load-store architecture**.

You CANNOT add two numbers that are in memory.  You must:
1. Load the first number from memory into a register
2. Load the second number from memory into a register
3. Add the two registers, placing the result in a register
4. Store the result from the register back to memory

```asm
  lw    t0, 0(a0)                                # load first value from memory
  lw    t1, 4(a0)                                # load second value from memory
  add   t2, t0, t1                               # add in registers
  sw    t2, 8(a0)                                # store result to memory
```

There is no `add memory[A], memory[B]` instruction.  This is fundamentally different from x86 CISC architecture, where you can operate on memory directly.

## The RISC-V Register File

RISC-V has exactly 32 general-purpose integer registers, each 32 bits wide on RV32.  They are named `x0` through `x31`.

Additionally, there is one special register:
- **pc** (Program Counter): holds the address of the current instruction

The 32 registers are called the **register file**.  Think of it as a tiny, fixed-size array inside the CPU:

```
  register_file[0]  = x0  (always zero)
  register_file[1]  = x1
  register_file[2]  = x2
  ...
  register_file[31] = x31
```

## Register x0: The Hardwired Zero

Register `x0` is special.  It is permanently hardwired to the value 0.  Writing to it has no effect.  Reading it always returns 0.

Why does this exist?  Because it eliminates the need for many special instructions:
- Need to load zero? Read `x0`
- Need to discard a result? Write to `x0`
- Need to compare against zero? Use `x0` as source operand

This is a brilliant design decision that simplifies the instruction set.

## ABI Register Names

While the hardware names are `x0`-`x31`, the RISC-V ABI (Application Binary Interface) assigns conventional names that describe each register's purpose.  **You will use the ABI names exclusively in this book**, because that is what professional RISC-V assembly uses.

### Complete Register Table

| Register | ABI Name | Purpose | Saved By |
|---:|---|---|---|
| x0 | zero | Hardwired zero | N/A |
| x1 | ra | Return address | Caller |
| x2 | sp | Stack pointer | Callee |
| x3 | gp | Global pointer | N/A |
| x4 | tp | Thread pointer | N/A |
| x5 | t0 | Temporary 0 | Caller |
| x6 | t1 | Temporary 1 | Caller |
| x7 | t2 | Temporary 2 | Caller |
| x8 | s0 / fp | Saved 0 / frame pointer | Callee |
| x9 | s1 | Saved 1 | Callee |
| x10 | a0 | Argument 0 / return value | Caller |
| x11 | a1 | Argument 1 / return value | Caller |
| x12 | a2 | Argument 2 | Caller |
| x13 | a3 | Argument 3 | Caller |
| x14 | a4 | Argument 4 | Caller |
| x15 | a5 | Argument 5 | Caller |
| x16 | a6 | Argument 6 | Caller |
| x17 | a7 | Argument 7 | Caller |
| x18 | s2 | Saved 2 | Callee |
| x19 | s3 | Saved 3 | Callee |
| x20 | s4 | Saved 4 | Callee |
| x21 | s5 | Saved 5 | Callee |
| x22 | s6 | Saved 6 | Callee |
| x23 | s7 | Saved 7 | Callee |
| x24 | s8 | Saved 8 | Callee |
| x25 | s9 | Saved 9 | Callee |
| x26 | s10 | Saved 10 | Callee |
| x27 | s11 | Saved 11 | Callee |
| x28 | t3 | Temporary 3 | Caller |
| x29 | t4 | Temporary 4 | Caller |
| x30 | t5 | Temporary 5 | Caller |
| x31 | t6 | Temporary 6 | Caller |

### Register Categories Explained

**Temporaries (t0-t6):**  Scratch registers.  Use freely for computation.  If you call a function, the function is allowed to overwrite these.  They are "caller-saved," meaning if you need their values after a call, you must save them yourself.

**Saved registers (s0-s11):**  If a function uses these, it must save the original value to the stack on entry and restore it on exit.  They are "callee-saved," meaning the called function guarantees they are unchanged when it returns.

**Argument registers (a0-a7):**  Used to pass arguments to functions and return values from functions.  `a0` is both the first argument and the first return value.

**Return address (ra):**  When `call` executes, it stores the return address in `ra`.  The function uses `ret` (which is actually `jalr zero, ra, 0`) to jump back.

**Stack pointer (sp):**  Points to the current top of the stack.  The stack grows downward on RISC-V.

## Visualizing Registers

At any point during execution, the register file looks like this:

```
  ┌──────────┬────────────┐
  │ Register │   Value    │
  ├──────────┼────────────┤
  │ zero     │ 0x00000000 │  always zero
  │ ra       │ 0x100000A4 │  return address from last call
  │ sp       │ 0x20082000 │  current stack pointer
  │ gp       │ 0x00000000 │  unused in our firmware
  │ tp       │ 0x00000000 │  unused in our firmware
  │ t0       │ 0x40070000 │  maybe holding UART base address
  │ t1       │ 0x00000020 │  maybe holding a bit mask
  │ t2       │ 0x00000000 │  scratch
  │ ...      │ ...        │
  │ a0       │ 0x00000041 │  maybe 'A' character for UART
  │ ...      │ ...        │
  └──────────┴────────────┘
```

Every instruction you write either:
1. Reads values from registers
2. Writes a value to a register
3. Both

## Worked Example From Our Firmware

Here is a line from `stack.s`:

```asm
  li    sp, STACK_TOP                            # set stack pointer to top of RAM
```

What happens:
1. `li` (load immediate) is a pseudoinstruction that loads a constant into a register
2. The target register is `sp` (x2), the stack pointer
3. The constant is `STACK_TOP`, which equals `0x20082000`
4. After execution, register x2 contains `0x20082000`

Here is a line from `uart.s`:

```asm
  lw    t1, 0x18(t0)                             # read UARTFR flag register
```

What happens:
1. `lw` (load word) reads 4 bytes from memory
2. The address is computed as: value in `t0` plus offset `0x18`
3. If `t0` = `0x40070000`, then address = `0x40070018`
4. The 4 bytes at that address are loaded into register `t1`

## Chapter Summary

Registers are fast storage inside the CPU.  RISC-V has 32 registers, each 32 bits.  `x0` is always zero.  All computation uses registers — memory is only for loading and storing data.  The ABI names (ra, sp, t0-t6, s0-s11, a0-a7) describe each register's conventional purpose.  Every assembly instruction reads from or writes to registers.
