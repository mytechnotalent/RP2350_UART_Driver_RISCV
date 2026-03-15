# Chapter 23: stack.s and vector_table.s — Line by Line

## Introduction

These are the two smallest source files in the project, yet they serve critical roles: one initializes the stack pointer so function calls work, the other provides a vector table for the boot ROM and trap system.

---

## Part 1: stack.s

### Full Source

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Init_Stack
.type Init_Stack, @function
Init_Stack:
  li    sp, STACK_TOP                            # set SP to top of RAM stack
  ret                                            # return
```

### Line-by-Line Analysis

#### Line: .include "constants.s"

```asm
.include "constants.s"
```

Textually inserts the entire contents of `constants.s` at this point.  After inclusion, the `STACK_TOP` symbol (0x20082000) is available for use.

#### Line: .section .text

```asm
.section .text                                   # code section
```

Places all following code in the `.text` section.  The linker script routes `.text` to flash memory starting after the IMAGE_DEF and vector table.

#### Line: .align 2

```asm
.align 2                                         # align to 4-byte boundary
```

Ensures the next instruction starts at a 4-byte aligned address.  Since `.align N` means 2^N on RISC-V, `.align 2` = 4-byte alignment.  This is required because 32-bit RISC-V instructions must be at least 2-byte aligned (and 4-byte alignment is preferred).

#### Line: .global Init_Stack

```asm
.global Init_Stack
```

Exports the `Init_Stack` symbol so the linker can find it.  Without this, `call Init_Stack` in `reset_handler.s` would fail with "undefined reference."

#### Line: .type Init_Stack, @function

```asm
.type Init_Stack, @function
```

Marks `Init_Stack` as a function symbol in the ELF symbol table.  This helps debuggers display backtraces and disassemblers show function boundaries.

#### Line: Init_Stack:

```asm
Init_Stack:
```

The label that marks the entry point of this function.  When `call Init_Stack` executes, the CPU jumps to this address.

#### Line: li sp, STACK_TOP

```asm
  li    sp, STACK_TOP                            # set SP to top of RAM stack
```

This is the most important line.  Let us break down exactly what happens:

1. The assembler substitutes `STACK_TOP` with `0x20082000`
2. `li sp, 0x20082000` is a pseudoinstruction
3. The assembler expands it to:
   ```asm
   lui   sp, 0x20082                             # sp = 0x20082000
   addi  sp, sp, 0x000                           # sp = 0x20082000 + 0 = 0x20082000
   ```
4. Actually, since the lower 12 bits are 0x000, the assembler may optimize to just `lui`:
   ```asm
   lui   sp, 0x20082                             # sp = 0x20082000
   ```

After execution, register `sp` (x2) contains `0x20082000`.

This is the top of the 520 KB SRAM.  The stack grows downward from here.  Every `call` instruction that pushes a return address, every `sw ra, offset(sp)` that saves a register — they all depend on `sp` being valid.

**This must be the first thing that runs after reset.**  Without a valid stack pointer, you cannot safely call any function.

#### Line: ret

```asm
  ret                                            # return
```

Returns to the caller.  Expands to `jalr zero, ra, 0`.

The `ra` register holds the return address that was stored when `call Init_Stack` executed in `Reset_Handler`.  After this `ret`, execution continues with the next instruction after `call Init_Stack` in `reset_handler.s`.

### Register State After Init_Stack

```
  Before:  sp = undefined (random/zero after reset)
  After:   sp = 0x20082000
           ra = return address in Reset_Handler (unchanged)
           All other registers: unchanged
```

---

## Part 2: vector_table.s

### Full Source

```asm
.include "constants.s"

.section .vectors, "ax"                          # vector table section
.align 2                                         # align to 4-byte boundary

.global _vectors                                 # export _vectors symbol
_vectors:
  .word Reset_Handler                            # reset handler address placeholder
  .word Default_Trap_Handler                     # default trap handler placeholder
```

### Line-by-Line Analysis

#### Line: .section .vectors, "ax"

```asm
.section .vectors, "ax"                          # vector table section
```

Places this data in a section named `.vectors` with flags:
- `a` = allocatable (takes space in memory)
- `x` = executable

The linker script aligns this section to 128 bytes and places it after the IMAGE_DEF block in flash, within the first 4 KB.

#### Line: .align 2

```asm
.align 2                                         # align to 4-byte boundary
```

Ensures `.word` directives that follow are word-aligned.

#### Line: .global _vectors

```asm
.global _vectors                                 # export _vectors symbol
```

Makes the `_vectors` symbol visible to the linker.  The linker script references it via `PROVIDE(__Vectors = ADDR(.vectors))`.

#### Line: _vectors:

```asm
_vectors:
```

Label marking the start of the vector table.

#### Line: .word Reset_Handler

```asm
  .word Reset_Handler                            # reset handler address placeholder
```

Emits a 4-byte word containing the address of `Reset_Handler`.  At assembly time, this is a relocation entry.  The linker fills in the actual address.

This is the first entry in the vector table.  On ARM Cortex-M, the vector table has a specific format (first word = initial SP, second word = reset vector).  On RISC-V, the vector table format is different — `mtvec` points directly to the handler.

In our firmware, this vector table serves as a **compatibility placeholder**.  The actual RISC-V trap handling is set up by `Init_Trap_Vector`, which writes the `Default_Trap_Handler` address to the `mtvec` CSR.

The boot ROM may also read this table during the boot process.

#### Line: .word Default_Trap_Handler

```asm
  .word Default_Trap_Handler                     # default trap handler placeholder
```

Second entry: the address of the default trap handler.  This provides a fallback for any trap or exception.

### Memory Layout

After linking, the vector table occupies 8 bytes in flash:

```
  Address      Content                    Meaning
  0x10000080   xx xx xx xx                Reset_Handler address
  0x10000084   yy yy yy yy                Default_Trap_Handler address
```

(The exact base address depends on the IMAGE_DEF size and 128-byte alignment.)

### Why Both Files Exist

The boot sequence uses these two files at different stages:

1. **vector_table.s**: consulted by the boot ROM during startup and provides compatibility structure
2. **stack.s**: called by Reset_Handler as the very first initialization step

Without `Init_Stack`, the stack is invalid and `call` instructions crash.  Without the vector table, the boot ROM may not recognize the firmware structure.

## Practice Problems

1. What register does `Init_Stack` modify?
2. If you removed `.global Init_Stack`, what error would occur?
3. How many bytes does the vector table occupy?
4. Why is the vector table aligned to 128 bytes?
5. What is the difference between the vector table's Reset_Handler word and the IMAGE_DEF's Reset_Handler word?

### Answers

1. Only `sp` (x2).  It does not modify `ra`, `t0`, or any other register.
2. Linker error: "undefined reference to `Init_Stack`" in `reset_handler.o`.
3. 8 bytes (two 4-byte words).
4. Because RISC-V `mtvec` requires the handler address to be aligned; the lower bits encode the vector mode.
5. They contain the same value (Reset_Handler's address), but serve different purposes: IMAGE_DEF is parsed by the boot ROM for initial entry; the vector table entry is for runtime trap handling and compatibility.

## Chapter Summary

`stack.s` contains a single function that sets `sp` to 0x20082000 (top of SRAM), enabling all subsequent function calls.  `vector_table.s` emits two 4-byte addresses (Reset_Handler and Default_Trap_Handler) in a 128-byte-aligned section, providing the boot ROM and trap system with entry points.  Both files are minimal but critical to firmware operation.
