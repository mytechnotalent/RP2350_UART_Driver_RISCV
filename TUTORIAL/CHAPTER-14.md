# Chapter 14: Assembler Directives — Controlling the Assembly Process

## Introduction

Directives are instructions to the assembler, not to the CPU.  They control how code is organized, where it is placed, what symbols are visible, and what data is embedded.  Every line in our source files starting with a dot (`.`) is a directive.

## Sections

### .section

```asm
  .section .text, "ax"
```

Tells the assembler to place the following code/data into a named section.  The linker script determines where each section ends up in memory.

Parameters:
- `.text` — section name
- `"ax"` — flags: `a` = allocatable (takes space in memory), `x` = executable

Common sections in our firmware:

| Section Name | Flags | Purpose |
|---|---|---|
| .picobin_block | "a" | Boot metadata (IMAGE_DEF) |
| .vectors | "ax" | Trap vector table |
| .text | "ax" | Executable code |

### .section Example from image_def.s

```asm
  .section .picobin_block, "a"                   # allocatable, non-executable data section
```

This creates a section named `.picobin_block` that will be placed first in flash by the linker script.  It contains boot metadata, not executable code (hence no `x` flag, though our file actually uses `"a"` only since the data is not instructions).

### .section Example from vector_table.s

```asm
  .section .vectors, "ax"                        # allocatable, executable section
```

The vector table must be executable because it contains the trap handler entry point.

## Symbol Visibility

### .global

```asm
  .global Reset_Handler                          # make symbol visible to linker
```

By default, symbols (labels) are local to their file.  `.global` exports them so the linker can resolve references from other files.

Every function that is called from another file needs `.global`:

```asm
  .global Init_Stack                             # called from reset_handler.s
  .global Init_XOSC                              # called from reset_handler.s
  .global UART_Init                              # called from reset_handler.s
  .global UART0_In                               # called from main.s
  .global UART0_Out                              # called from main.s
  .global main                                   # jumped to from reset_handler.s
```

### .type

```asm
  .type Init_Stack, @function                    # mark as function symbol
```

This tells the assembler (and debugger) that the symbol is a function entry point, not a data label.  This affects:
- Debug information generation
- Disassembler output formatting
- ELF symbol table entries

## Alignment

### .align

```asm
  .align 2                                       # align to 2^2 = 4 bytes
```

Inserts padding bytes (zeros) until the current position is aligned to a 2ⁿ byte boundary.

**Warning**: on RISC-V, `.align N` means align to 2^N bytes, NOT N bytes.

| Directive | Alignment |
|---|---|
| .align 0 | 1 byte (no alignment) |
| .align 1 | 2 bytes |
| .align 2 | 4 bytes (word) |
| .align 3 | 8 bytes |
| .align 4 | 16 bytes |

In `vector_table.s`, the linker script uses `ALIGN(128)` to ensure the vector table is 128-byte aligned, as required by the RISC-V `mtvec` specification (the lower bits of `mtvec` encode the mode).

## Data Embedding

### .word

```asm
  .word 0xFFFFDED3                               # emit a 32-bit value
```

Places a literal 32-bit value into the output at the current position.  This is NOT an instruction — it is raw data.

Used extensively in `image_def.s`:

```asm
  .word 0xFFFFDED3                               # picobin start marker
  .word 0x10210142                               # image type item
  .word 0x000001FF                               # last item flag
  .word 0x00001101                               # image type: EXE + RISCV + RP2350
```

And in `vector_table.s`:

```asm
  .word Reset_Handler                            # first vector: reset entry point
  .word Default_Trap_Handler                     # second vector: default trap handler
```

Here, `.word Reset_Handler` emits the 32-bit address of the `Reset_Handler` symbol.  The linker resolves this address.

### .byte

```asm
  .byte 0x41                                     # emit a single byte
```

### .hword / .half

```asm
  .hword 0x1234                                  # emit a 16-bit value
```

### .ascii / .asciz

```asm
  .ascii "Hello"                                 # emit string bytes (no null terminator)
  .asciz "Hello"                                 # emit string bytes with null terminator
```

Our firmware does not use these, but they are common in programs that need string constants.

## Constant Definitions

### .equ

```asm
  .equ UART0_BASE, 0x40070000                    # define a symbolic constant
```

`.equ` assigns a value to a name.  It does NOT emit any data or code.  It is a pure text substitution at assembly time.

Our `constants.s` file consists entirely of `.equ` directives:

```asm
  .equ STACK_TOP, 0x20082000
  .equ STACK_LIMIT, 0x2007A000
  .equ XOSC_BASE, 0x40048000
  .equ CLOCKS_BASE, 0x40010000
  .equ RESETS_BASE, 0x40020000
  .equ IO_BANK0_BASE, 0x40028000
  .equ PADS_BANK0_BASE, 0x40038000
  .equ UART0_BASE, 0x40070000
  ...
```

These are used throughout the firmware:
```asm
  li    t0, UART0_BASE                           # assembler substitutes 0x40070000
```

## File Inclusion

### .include

```asm
  .include "constants.s"                         # include another assembly file
```

Textually inserts the content of another file at this point, exactly like C's `#include`.  Every source file in our firmware starts with:

```asm
  .include "constants.s"
```

This makes all the `.equ` definitions available.

## Labels

Labels are not directives per se, but they work with directives to define code structure:

```asm
Reset_Handler:                                   # global label (function entry)
  call  Init_Stack
  ...

.Lwait_xosc:                                     # local label (branch target)
  lw    t1, XOSC_STATUS(t0)
  bgez  t1, .Lwait_xosc
```

The `.L` prefix makes a label local (not exported to symbol table).  This is a GNU assembler convention.

## Putting It All Together

Here is the complete structure of a typical source file in our firmware:

```asm
  .include "constants.s"                         # 1. include constant definitions

  .section .text                                 # 2. place code in .text section

  .global My_Function                            # 3. export function symbol
  .type My_Function, @function                   # 4. mark as function type

My_Function:                                     # 5. function label
  # ... instructions ...                         # 6. function body
  ret                                            # 7. return

.Llocal_label:                                   # 8. local branch target
  # ... instructions ...
```

## Practice Problems

1. What is the difference between `.word Reset_Handler` and `call Reset_Handler`?
2. What does `.align 2` do?
3. If you remove `.global Init_Stack`, what error would you get?
4. What does `.equ` actually emit into the binary?
5. What is the purpose of `.type My_Func, @function`?

### Answers

1. `.word Reset_Handler` emits the 4-byte address of Reset_Handler as data.  `call Reset_Handler` emits instructions that jump to Reset_Handler.
2. Pads with zeros until the current address is 4-byte aligned (2² = 4).
3. Linker error: "undefined reference to Init_Stack" in any other file that calls it.
4. Nothing.  `.equ` is a compile-time symbol definition only.
5. It marks the symbol as a function in the ELF symbol table, helping debuggers and disassemblers.

## Chapter Summary

Directives control assembly: `.section` places code in named sections, `.global` exports symbols, `.type` marks function types, `.align` enforces alignment, `.word` emits raw data, `.equ` defines constants, and `.include` pulls in other files.  These are the scaffolding that organizes your assembly code into a structured binary the linker can arrange in memory.
