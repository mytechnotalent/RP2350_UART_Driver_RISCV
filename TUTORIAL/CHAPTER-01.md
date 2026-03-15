# Chapter 1: What Is a Computer?

## Introduction

A computer is a machine that executes instructions.  That is technically all it is.  Everything else, the screen, the keyboard, the mouse, the network, the storage, those are all peripherals.  The core of a computer is a processor that reads an instruction, decodes what it means, executes it, and moves to the next instruction.  It does this billions of times per second.

This book teaches you how to program a real processor at the lowest possible level.  You will write every instruction by hand in assembly language.  You will understand every single bit and byte that makes the hardware function.  By the end of this book, you will have built a working UART echo program on the RP2350 microcontroller using RISC-V assembly.

## The Fetch-Decode-Execute Cycle

Every processor in existence follows this loop:

```
1. FETCH:   Read the next instruction from memory
2. DECODE:  Figure out what the instruction means
3. EXECUTE: Perform the operation
4. REPEAT:  Move to the next instruction
```

This is called the fetch-decode-execute cycle, and it is the heartbeat of every CPU.

When you write assembly, you are writing the exact instructions the CPU will fetch.  There is no compiler translating your intent.  There is no runtime interpreting your code.  The CPU reads your instruction bytes directly from memory and executes them.

## The Three Core Components

A minimal computer system consists of three things:

### 1. CPU (Central Processing Unit)

The CPU is the brain.  It contains:
- **Registers**: tiny storage cells inside the CPU where data is held during computation.  On our processor, each register holds exactly 32 bits (4 bytes).
- **ALU (Arithmetic Logic Unit)**: the circuit that performs math and logic operations like addition, subtraction, AND, OR, and shifting.
- **Control Unit**: the circuit that manages the fetch-decode-execute cycle, deciding what happens next based on the current instruction.
- **Program Counter (PC)**: a special register that holds the memory address of the *next* instruction to fetch.  After each instruction, the PC advances (unless a branch or jump changes it).

### 2. Memory

Memory stores both instructions and data.  The CPU uses numerical addresses to access specific locations in memory.  Think of memory as a giant array of bytes, where each byte has a unique address starting from 0.

On our RP2350 microcontroller:
- Flash memory starts at address `0x10000000`.  This is where your program code lives.
- SRAM starts at address `0x20000000`.  This is where variables and the stack live.

### 3. Peripherals

Peripherals are hardware blocks that do specialized work: sending serial data (UART), controlling pin voltages (GPIO), generating precise timing (timers), and more.

On the RP2350, peripherals are controlled by writing to specific memory addresses.  This is called **memory-mapped I/O**.  From the CPU's perspective, writing to a UART register is identical to writing to a RAM location.  The hardware intercepts the write and does something with it.

## Microcontroller vs Desktop Computer

A desktop computer has an operating system (Windows, macOS, Linux) that manages programs, memory, and hardware access for you.  Your program never talks to hardware directly.

A microcontroller has **no operating system**.  Your code runs directly on the hardware.  You are responsible for:
- Setting up the stack pointer
- Configuring the clock source
- Bringing peripherals out of reset
- Configuring pin functions
- Programming peripheral registers
- Handling any errors or traps

This is called **bare-metal programming**.  There is nothing between your code and the silicon.

## What Is RP2350?

RP2350 is a dual-architecture microcontroller made by Raspberry Pi.  It has:
- Two ARM Cortex-M33 cores
- Two Hazard3 RISC-V cores
- 520 KB of SRAM
- External flash support via XIP (Execute In Place)
- Rich peripheral set: UART, SPI, I2C, GPIO, PWM, ADC, timers

The chip can boot into either ARM mode or RISC-V mode.  This entire book uses the **RISC-V** execution path on the **Hazard3** core.

## What Is RISC-V?

RISC-V (pronounced "risk five") is an open-standard instruction set architecture (ISA).  Unlike proprietary architectures (ARM, x86), anyone can implement a RISC-V processor without licensing fees.

The specific RISC-V configuration we use in this project:

| Extension | Meaning |
|---|---|
| RV32 | 32-bit base integer ISA |
| I | Base integer instruction set |
| M | Multiply and divide instructions |
| A | Atomic memory operations |
| C | Compressed (16-bit) instruction support |
| Zicsr | Control and Status Register instructions |

The full ISA string is `rv32imac_zicsr` and the ABI (Application Binary Interface) is `ilp32`, meaning int, long, and pointer types are all 32 bits.

## Why Assembly Language?

Assembly language is a human-readable representation of machine code.  Each assembly instruction maps (almost) directly to one machine instruction the CPU executes.

When you write:
```asm
  li    t0, 0x40070000                           # load UART0 base address into t0
```

The assembler converts this into the exact bytes the CPU will read and execute.  There is no hidden magic.

Learning assembly gives you:
1. **Complete understanding** of what software really does at the hardware level
2. **Ability to read and debug** any code, including compiler output
3. **Precise control** over timing, register usage, and memory layout
4. **Foundation** for understanding operating systems, compilers, and security

## What We Are Building

By the end of this 30-chapter book, you will have built and understood every single line of a complete RP2350 RISC-V firmware that:

1. Boots the processor from reset
2. Sets up the stack pointer
3. Configures the trap vector
4. Initializes the crystal oscillator
5. Enables the peripheral clock
6. Releases peripherals from reset
7. Configures GPIO pins for UART
8. Programs UART baud rate and line format
9. Enables UART transmit and receive
10. Runs an infinite echo loop (every character you type comes back)

## Chapter Summary

A computer fetches, decodes, and executes instructions in a loop.  A microcontroller is a computer on a single chip with no operating system.  RP2350 is a microcontroller that can run RISC-V code on its Hazard3 core.  Assembly language lets you write the exact instructions the CPU executes.  This book teaches every bit and byte from power-on to a working UART terminal.
