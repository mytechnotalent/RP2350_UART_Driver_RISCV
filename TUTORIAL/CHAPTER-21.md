# Chapter 21: image_def.s — Boot Metadata Line by Line

## Introduction

When the RP2350 powers on, the boot ROM scans the first 4 KB of flash looking for a valid IMAGE_DEF block.  This metadata tells the boot ROM what kind of image is in flash, which architecture to boot, and where execution should begin.  This chapter explains every single byte.

## Full Source: image_def.s

```asm
.include "constants.s"

.section .picobin_block, "a"                     # place in picobin_block section
.align  2                                        # align to 4-byte boundary
embedded_block:
.word  0xffffded3                                # PICOBIN_BLOCK_MARKER_START
.byte  0x42                                      # PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE
.byte  0x1                                       # item is 1 word in size
.hword 0x1101                                    # EXE + RISCV + RP2350

.byte  0x44                                      # PICOBIN_BLOCK_ITEM_1BS_ENTRY_POINT
.byte  0x3                                       # 3 words to next item
.byte  0x0                                       # pad
.byte  0x0                                       # pad
.word  Reset_Handler                             # RISC-V reset entry point
.word  STACK_TOP                                 # initial stack pointer value

.byte  0xff                                      # PICOBIN_BLOCK_ITEM_2BS_LAST
.hword (embedded_block_end - embedded_block - 16) / 4
.byte  0x0                                       # pad
.word  0x0                                       # relative pointer to next block (0 = self)
.word  0xab123579                                # PICOBIN_BLOCK_MARKER_END
embedded_block_end:
```

## Section and Alignment

```asm
.section .picobin_block, "a"                     # place in picobin_block section
```

This places the data in a section named `.picobin_block` with flag `"a"` (allocatable — it takes space in the output).  The linker script places this section FIRST in flash via the `.embedded_block` output section.

```asm
.align  2                                        # align to 4-byte boundary
```

Ensures the block starts at a 4-byte aligned address.  Since it is first in flash, it starts at exactly 0x10000000.

```asm
embedded_block:
```

A local label marking the start of the block.  Used later to calculate the block size.

## Start Marker

```asm
.word  0xffffded3                                # PICOBIN_BLOCK_MARKER_START
```

This is a magic number.  The boot ROM scans flash looking for this specific 32-bit pattern.  When found, it begins parsing the picobin block.

In memory (little-endian at address 0x10000000):
```
  Address     Byte
  0x10000000  0xD3    (least significant byte)
  0x10000001  0xDE
  0x10000002  0xFF
  0x10000003  0xFF    (most significant byte)
```

## Image Type Item

```asm
.byte  0x42                                      # PICOBIN_BLOCK_ITEM_1BS_IMAGE_TYPE
```

This byte is the item header.  `0x42` encodes:
- Item type = IMAGE_TYPE
- Size class = 1BS (1-byte-size, meaning the next byte gives the item payload size in words)

```asm
.byte  0x1                                       # item is 1 word in size
```

The payload of this item is 1 word (4 bytes).

```asm
.hword 0x1101                                    # EXE + RISCV + RP2350
```

Wait — this is `.hword` (2 bytes), but we said the payload is 1 word (4 bytes).  The remaining 2 bytes are implicit padding/flags.  Let us decode 0x1101:

In binary: `0001 0001 0000 0001`

| Bits | Value | Meaning |
|---|---|---|
| [3:0] | 0x1 | Image type = EXE (executable) |
| [7:4] | 0x0 | Security flags |
| [11:8] | 0x1 | Architecture = RISC-V (1) vs ARM (0) |
| [15:12] | 0x1 | Chip = RP2350 |

Breaking it down:
- **0x01**: This is an executable image (not a data block)
- **0x01 in bits [11:8]**: RISC-V architecture (ARM would be 0x00)
- **0x01 in bits [15:12]**: Targets RP2350 (not RP2040)

If we were building for ARM, this would be `0x1001` instead.

## Entry Point Item

```asm
.byte  0x44                                      # PICOBIN_BLOCK_ITEM_1BS_ENTRY_POINT
```

Item header `0x44` = ENTRY_POINT item type with 1BS size encoding.

```asm
.byte  0x3                                       # 3 words to next item
```

This item's data spans 3 words (12 bytes) before the next item begins.

```asm
.byte  0x0                                       # pad
.byte  0x0                                       # pad
```

Two padding bytes to reach 4-byte alignment.  The item header was 2 bytes; these 2 pad bytes complete a 4-byte-aligned header.

```asm
.word  Reset_Handler                             # RISC-V reset entry point
```

This emits the 32-bit address of `Reset_Handler`.  The assembler emits a relocation; the linker fills in the actual address (something like 0x10000088).

When the boot ROM processes this item, it sets the initial PC to this address.  **This is where your code starts executing.**

```asm
.word  STACK_TOP                                 # initial stack pointer value
```

This emits `0x20082000` (the value of the STACK_TOP constant).  The boot ROM may use this to set the initial stack pointer before jumping to the entry point.

Note: our firmware also sets SP explicitly in `Init_Stack`, so this is defense in depth.

The third word (bytes 9-12 of the 3-word payload) is the padding/header area above.

## Last Item Marker

```asm
.byte  0xff                                      # PICOBIN_BLOCK_ITEM_2BS_LAST
```

`0xFF` marks the LAST item in the block.  The boot ROM stops parsing here.

```asm
.hword (embedded_block_end - embedded_block - 16) / 4
```

This computes the block body size in words.  The expression:
- `embedded_block_end - embedded_block` = total block size in bytes
- Subtract 16 (the start marker 4 bytes + end marker 4 bytes + last item overhead 8 bytes... the exact accounting follows the picobin spec)
- Divide by 4 to get word count

The assembler evaluates this expression at assembly time.

```asm
.byte  0x0                                       # pad
```

Padding to maintain alignment.

## Block Loop Pointer

```asm
.word  0x0                                       # relative pointer to next block (0 = self)
```

Picobin blocks can be chained.  A value of 0 means "no next block" or "loop to self."  Our firmware has only one block.

## End Marker

```asm
.word  0xab123579                                # PICOBIN_BLOCK_MARKER_END
```

The closing magic number.  The boot ROM verifies this matches to confirm the block is valid.

```asm
embedded_block_end:
```

Label marking the end, used in the size calculation above.

## Complete Binary Dump

At address 0x10000000, the raw bytes in flash look like this:

```
  Offset  Bytes                     Meaning
  0x00    D3 DE FF FF               Start marker (0xFFFFDED3 little-endian)
  0x04    42 01 01 11               Image type item: RISC-V EXE for RP2350
  0x08    44 03 00 00               Entry point item header
  0x0C    xx xx xx xx               Reset_Handler address (linker-resolved)
  0x10    00 20 08 20               STACK_TOP = 0x20082000 (little-endian)
  0x14    FF xx xx 00               Last item marker + size
  0x18    00 00 00 00               Next block pointer (self)
  0x1C    79 35 12 AB               End marker (0xAB123579 little-endian)
```

Total size: 32 bytes (8 words).

## Boot ROM Sequence

1. Power on → internal boot ROM executes
2. Boot ROM initializes XIP for basic flash access
3. Boot ROM scans flash starting at 0x10000000
4. Finds start marker 0xFFFFDED3 at offset 0
5. Parses IMAGE_TYPE item → confirms RISC-V EXE for RP2350
6. Parses ENTRY_POINT item → reads Reset_Handler address and STACK_TOP
7. Verifies end marker 0xAB123579
8. Switches to RISC-V core (if not already)
9. Sets PC to Reset_Handler address
10. Our firmware begins executing

## Practice Problems

1. What happens if the start marker is missing or wrong?
2. Why does IMAGE_TYPE have `0x1101` instead of `0x1001`?
3. What address does the boot ROM set PC to?
4. Why is there a `.hword` instead of `.word` for the image type value?
5. What is the end marker value?

### Answers

1. The boot ROM fails to find a valid image and enters BOOTSEL mode (appears as USB drive).
2. Bit 8 = 1 means RISC-V.  `0x1001` has bit 8 = 0, which means ARM.
3. The address of `Reset_Handler`, as resolved by the linker (embedded in the entry point item).
4. Because the IMAGE_TYPE item's 1-word payload starts with the 2-byte type value; the remaining 2 bytes are part of the item structure.
5. 0xAB123579

## Chapter Summary

The IMAGE_DEF block is the first data in flash.  It starts with magic marker 0xFFFFDED3, contains an image type item (0x1101 = RISC-V EXE for RP2350), an entry point item (Reset_Handler address + STACK_TOP), a last-item marker, and ends with magic marker 0xAB123579.  The boot ROM parses this block to determine the architecture and entry point, then jumps to Reset_Handler to begin our firmware.
