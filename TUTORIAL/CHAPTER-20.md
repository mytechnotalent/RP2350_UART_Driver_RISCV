# Chapter 20: The Build Pipeline — From Assembly to UF2

## Introduction

Writing source code is only half the battle.  This chapter walks through the entire toolchain pipeline: how `build.bat` transforms `.s` files into a `.uf2` firmware image ready for the RP2350.

## The Four-Stage Pipeline

```
  .s files  ──►  Assembler  ──►  .o files  ──►  Linker  ──►  .elf file
                                                                │
  .uf2 file  ◄──  uf2conv.py  ◄──  .bin file  ◄──  objcopy  ◄──┘
```

### Stage 1: Assembly (.s → .o)

The assembler reads human-readable assembly source and produces machine code in object file format.

```bat
riscv32-unknown-elf-as -g -march=rv32imac_zicsr -mabi=ilp32 stack.s -o stack.o
```

**Flags explained:**

| Flag | Purpose |
|---|---|
| `-g` | Include debug information (symbol names, line numbers) |
| `-march=rv32imac_zicsr` | Target ISA: 32-bit, integer, multiply, atomic, compressed, CSR |
| `-mabi=ilp32` | ABI: int=32, long=32, pointer=32 bits |

**What the assembler does:**
1. Reads `stack.s` (and its `.include "constants.s"`)
2. Substitutes `.equ` symbols with their values
3. Expands pseudoinstructions (`li` → `lui`+`addi`, `call` → `auipc`+`jalr`, etc.)
4. Encodes each instruction into its binary representation
5. Records undefined symbols (like `STACK_TOP` from `.equ`, `Reset_Handler` from another file) in a relocation table
6. Outputs `stack.o` in ELF (Executable and Linkable Format) object file format

Each `.s` file produces one `.o` file.  All 11 source files are assembled independently:

```
  vector_table.s  →  vector_table.o
  reset_handler.s →  reset_handler.o
  stack.s         →  stack.o
  xosc.s          →  xosc.o
  reset.s         →  reset.o
  coprocessor.s   →  coprocessor.o
  uart.s          →  uart_module.o
  gpio.s          →  gpio.o
  delay.s         →  delay.o
  main.s          →  main.o
  image_def.s     →  image_def.o
```

Note: `uart.s` produces `uart_module.o` (not `uart.o`) to avoid name collision with the final `uart.elf`.

### Stage 2: Linking (.o → .elf)

The linker combines all object files into a single executable.

```bat
riscv32-unknown-elf-ld -g -T linker.ld vector_table.o reset_handler.o stack.o xosc.o reset.o coprocessor.o uart_module.o gpio.o delay.o main.o image_def.o -o uart.elf
```

**Flags explained:**

| Flag | Purpose |
|---|---|
| `-g` | Preserve debug information |
| `-T linker.ld` | Use our linker script for section placement |
| (object files) | Input files to combine |
| `-o uart.elf` | Output ELF executable |

**What the linker does:**
1. Reads all `.o` files and the linker script
2. Assigns absolute addresses to all sections based on the linker script
3. Resolves all symbol references (e.g., `call Init_Stack` gets the actual address of `Init_Stack`)
4. Applies relocations (patching instruction encodings with resolved addresses)
5. Checks the ASSERT (vector table within first 4 KB)
6. Outputs `uart.elf` — a complete executable with absolute addresses

**Symbol resolution example:**

In `reset_handler.o`, `call Init_Stack` has a relocation entry saying "patch this instruction pair with the address of Init_Stack."  The linker finds `Init_Stack` in `stack.o`, determines its absolute address (say 0x100000C0), and patches the auipc+jalr encoding.

### Stage 3: Binary Extraction (.elf → .bin)

```bat
riscv32-unknown-elf-objcopy -O binary uart.elf uart.bin
```

The ELF file contains headers, symbol tables, debug info, and multiple sections with metadata.  `objcopy -O binary` strips everything except the raw content of loadable sections, concatenated in address order.

The result is a flat binary: the exact bytes that should be written to flash starting at address 0x10000000.

### Stage 4: UF2 Conversion (.bin → .uf2)

```bat
python uf2conv.py -b 0x10000000 -f 0xe48bff5a -o uart.uf2 uart.bin
```

**Flags explained:**

| Flag | Purpose |
|---|---|
| `-b 0x10000000` | Base address (where this data goes in flash) |
| `-f 0xe48bff5a` | Family ID: RP2350 RISC-V |
| `-o uart.uf2` | Output file |
| `uart.bin` | Input binary |

**UF2 format explained:**

UF2 (USB Flashing Format) is a Microsoft-designed format for flashing microcontrollers over USB Mass Storage.  When you put the RP2350 in BOOTSEL mode, it appears as a USB drive.  Dragging a `.uf2` file onto it triggers the boot ROM to write the contained data to flash.

Each UF2 block contains:
- 32-byte header (magic numbers, target address, data size, flags, family ID)
- 476 bytes of payload data
- 4-byte final magic number

The family ID `0xE48BFF5A` tells the boot ROM this image is for RP2350 RISC-V.  ARM images use a different family ID.

## Toolchain Path Auto-Detection

The build script auto-detects the RISC-V toolchain:

```bat
where %TOOLCHAIN_PREFIX%-as >nul 2>nul
if errorlevel 1 (
    if exist "%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin\..." 
        set "PATH=%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin;%PATH%"
)
```

It checks (in order):
1. Is the toolchain already on PATH?
2. Is RISCV_TOOLCHAIN_BIN environment variable set?
3. Is the toolchain at `%USERPROFILE%\OneDrive\Documents\riscv-toolchain-14\bin`?
4. Is the toolchain at `%USERPROFILE%\Documents\riscv-toolchain-14\bin`?

If none found, the build fails with a clear error message.

## Object File Contents

You can examine what the assembler produced using `objdump`:

```bat
riscv32-unknown-elf-objdump -d stack.o
```

This would show:
```
stack.o:     file format elf32-littleriscv

Disassembly of section .text:

00000000 <Init_Stack>:
   0:   20082137          lui     sp,0x20082
   4:   00010113          addi    sp,sp,0
   8:   00008067          jalr    zero,0(ra)
```

Notice: addresses start at 0 because the object file has not been linked yet.  The linker will relocate these to their final flash addresses.

## Examining the Final ELF

```bat
riscv32-unknown-elf-objdump -d uart.elf
```

Now addresses are absolute:
```
10000088 <Init_Stack>:
10000088:   20082137          lui     sp,0x20082
1000008c:   00010113          addi    sp,sp,0
10000090:   00008067          jalr    zero,0(ra)
```

## Practice Problems

1. What does the assembler do with `li t0, 0x40070000`?
2. Why does the linker need all object files at once?
3. What does `objcopy -O binary` discard?
4. What is the RP2350 RISC-V UF2 family ID?
5. What happens if you use the wrong family ID?

### Answers

1. Expands it to `lui t0, 0x40070` + `addi t0, t0, 0` and encodes both as 32-bit machine instructions.
2. To resolve cross-file references (e.g., `call Init_Stack` in reset_handler.o needs the address of `Init_Stack` from stack.o).
3. All ELF metadata: headers, symbol tables, section tables, debug info, relocations.  Only raw loadable bytes remain.
4. 0xE48BFF5A
5. The RP2350 boot ROM ignores the UF2 file (wrong architecture family).

## Chapter Summary

The build pipeline has four stages: assemble (.s→.o), link (.o→.elf), extract binary (.elf→.bin), convert to UF2 (.bin→.uf2).  The assembler encodes instructions and creates relocation entries.  The linker resolves symbols and assigns absolute addresses per the linker script.  Objcopy strips metadata to create a flat binary.  UF2conv wraps the binary in Microsoft's USB flashing format with the RP2350 RISC-V family ID.
