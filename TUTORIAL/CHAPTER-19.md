# Chapter 19: The Linker Script — Placing Code in Memory

## Introduction

The assembler converts each `.s` file into an object file.  But object files do not know where they will live in memory.  The linker script tells the linker exactly where to place every section in the final binary.  This chapter explains every line of our `linker.ld`.

## Why a Linker Script?

On a desktop OS, the operating system decides where to load your program.  On bare metal, YOU must decide.  The linker script specifies:
1. What memory regions exist (flash, RAM) and their addresses
2. Which sections go in which regions
3. The order of sections within each region
4. Symbol definitions (stack top, vector table address)

## Full Source: linker.ld

```
ENTRY(Reset_Handler)

__XIP_BASE   = 0x10000000;
__XIP_SIZE   = 32M;

__SRAM_BASE  = 0x20000000;
__SRAM_SIZE  = 512K;
__STACK_SIZE = 32K;

MEMORY
{
  RAM   (rwx) : ORIGIN = __SRAM_BASE, LENGTH = __SRAM_SIZE
  FLASH (rx)  : ORIGIN = __XIP_BASE,  LENGTH = __XIP_SIZE
}

PHDRS
{
  text PT_LOAD FLAGS(5);
}

SECTIONS
{
  . = ORIGIN(FLASH);

  .embedded_block :
  {
    KEEP(*(.embedded_block))
    KEEP(*(.picobin_block))
  } > FLASH :text

  .vectors ALIGN(128) :
  {
    KEEP(*(.vectors))
  } > FLASH :text

  ASSERT(((ADDR(.vectors) - ORIGIN(FLASH)) < 0x1000),
         "Vector table must be in first 4KB of flash")

  .text :
  {
    . = ALIGN(4);
    *(.text*)
    *(.rodata*)
  } > FLASH :text

  __StackTop   = ORIGIN(RAM) + LENGTH(RAM);
  __StackLimit = __StackTop - __STACK_SIZE;
  __stack      = __StackTop;

  .stack (NOLOAD) : { . = ALIGN(8); } > RAM

  PROVIDE(__Vectors = ADDR(.vectors));
}
```

## Line-by-Line Walkthrough

### ENTRY(Reset_Handler)

```
ENTRY(Reset_Handler)
```

Declares `Reset_Handler` as the program's entry point.  The entry point is recorded in the ELF header.  Debugging tools use this to know where execution begins.  The actual hardware boot flow uses the IMAGE_DEF entry point, but ENTRY ensures the linker does not garbage-collect the Reset_Handler symbol.

### Memory Constants

```
__XIP_BASE   = 0x10000000;
__XIP_SIZE   = 32M;
```

Defines the flash base address and size.  0x10000000 is where the XIP controller maps external flash.  32 MB is the maximum flash window size, though the actual flash chip may be smaller (typically 2-4 MB on Pico 2).

```
__SRAM_BASE  = 0x20000000;
__SRAM_SIZE  = 512K;
__STACK_SIZE = 32K;
```

Defines RAM parameters.  The RP2350 has 520 KB SRAM, but we use a 512 KB non-secure window.  The stack gets 32 KB of this.

### MEMORY Block

```
MEMORY
{
  RAM   (rwx) : ORIGIN = __SRAM_BASE, LENGTH = __SRAM_SIZE
  FLASH (rx)  : ORIGIN = __XIP_BASE,  LENGTH = __XIP_SIZE
}
```

Declares two memory regions:
- **RAM**: starts at 0x20000000, 512 KB, readable/writable/executable
- **FLASH**: starts at 0x10000000, 32 MB, readable/executable (not writable at runtime)

The flags (rwx, rx) tell the linker what operations are valid in each region.

### PHDRS Block

```
PHDRS
{
  text PT_LOAD FLAGS(5);
}
```

Defines a program header for the ELF output.  PT_LOAD means this segment should be loaded into memory.  FLAGS(5) = read(4) + execute(1) = 0b101.  This is used by tools that process the ELF file.

### SECTIONS Block — Location Counter

```
SECTIONS
{
  . = ORIGIN(FLASH);
```

The dot (`.`) is the **location counter** — it tracks the current output address.  Setting it to ORIGIN(FLASH) means section placement starts at 0x10000000.

### Section: .embedded_block

```
  .embedded_block :
  {
    KEEP(*(.embedded_block))
    KEEP(*(.picobin_block))
  } > FLASH :text
```

This is the FIRST section placed in flash.  It collects all content from `.embedded_block` and `.picobin_block` input sections across all object files.

`KEEP()` prevents the linker from discarding these sections during garbage collection.  Since no code references the IMAGE_DEF data, the linker might otherwise optimize it away.

**Critical**: this must be first.  The boot ROM looks for the IMAGE_DEF at the start of flash.

### Section: .vectors

```
  .vectors ALIGN(128) :
  {
    KEEP(*(.vectors))
  } > FLASH :text
```

The vector table is aligned to 128 bytes (2⁷).  This alignment is required by the RISC-V `mtvec` CSR — the lower bits of `mtvec` encode the vector mode, so the handler address must be aligned.

`KEEP()` prevents discard because the vector table is referenced by the boot ROM, not by linker-traceable code.

### Vector Table Assertion

```
  ASSERT(((ADDR(.vectors) - ORIGIN(FLASH)) < 0x1000),
         "Vector table must be in first 4KB of flash")
```

A compile-time check.  If the vector table ends up more than 4096 bytes from the start of flash, the link fails with an error.  The boot ROM only scans the first 4 KB for metadata.

### Section: .text

```
  .text :
  {
    . = ALIGN(4);
    *(.text*)
    *(.rodata*)
  } > FLASH :text
```

All executable code (`*.text*`) and read-only data (`*.rodata*`) from all object files go here, aligned to 4 bytes.

The wildcard `*(.text*)` matches .text, .text.Init_Stack, .text.unlikely, etc.

### Stack Symbols

```
  __StackTop   = ORIGIN(RAM) + LENGTH(RAM);
  __StackLimit = __StackTop - __STACK_SIZE;
  __stack      = __StackTop;
```

Defines symbols for the stack:
- `__StackTop` = 0x20000000 + 512K = 0x20080000
- `__StackLimit` = 0x20080000 - 32K = 0x20078000
- `__stack` = alias for __StackTop

**Note**: our firmware uses `STACK_TOP = 0x20082000` from `constants.s`, which is slightly different.  The linker symbols are available but our code uses the `.equ` constant directly.

### Stack Section

```
  .stack (NOLOAD) : { . = ALIGN(8); } > RAM
```

`(NOLOAD)` means this section does not contain data to be loaded from flash.  It just reserves space in RAM.  The `.stack` section is empty but ensures the linker accounts for the stack region.

### PROVIDE

```
  PROVIDE(__Vectors = ADDR(.vectors));
```

Creates a symbol `__Vectors` pointing to the vector table address, but only if no other file defines it.  `PROVIDE` is a weak definition.

## Memory Layout After Linking

```
  Flash:
  0x10000000  ┌──────────────────┐
              │ .embedded_block  │  IMAGE_DEF (~44 bytes)
              │ (picobin_block)  │
  0x10000080  ├──────────────────┤  (128-byte aligned)
              │ .vectors         │  8 bytes (2 words)
  0x10000088  ├──────────────────┤
              │ .text            │  All code (~500 bytes)
              │                  │
              └──────────────────┘

  RAM:
  0x20000000  ┌──────────────────┐
              │ (unused)         │
              │                  │
  0x20078000  ├──────────────────┤  __StackLimit
              │ Stack (32 KB)    │  grows downward ↓
  0x20080000  └──────────────────┘  __StackTop
```

## Practice Problems

1. What address does the IMAGE_DEF block start at?
2. Why is the vector table aligned to 128 bytes?
3. What does `KEEP()` prevent?
4. If you added a `.data` section with initialized variables, where would it go?
5. What is the location counter (`.`)?

### Answers

1. 0x10000000 (start of flash)
2. Because RISC-V `mtvec` uses the lower bits as mode flags; the handler address must be aligned.
3. The linker from discarding sections that are not directly referenced by code (garbage collection).
4. In FLASH for the initial values, with a copy-to-RAM step at startup (AT>FLASH, >RAM).  Our firmware has no .data section.
5. A linker variable that tracks the current output address during section placement.

## Chapter Summary

The linker script defines memory regions (FLASH at 0x10000000, RAM at 0x20000000), places the IMAGE_DEF first in flash (required by boot ROM), aligns the vector table to 128 bytes, collects all code in .text, and defines stack symbols.  KEEP prevents garbage collection of unreferenced but critical sections.  ASSERT catches layout errors at link time.
