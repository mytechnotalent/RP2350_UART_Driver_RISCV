# RULES — 30-Chapter Assembly Tutorial Book

Rules for generating comprehensive 30-chapter tutorial books that teach bare-metal assembly programming on microcontrollers (RISC-V or ARM).

---

## Scope

This document covers the full production of a 30-chapter tutorial stored in a `TUTORIAL/` folder alongside a driver project repo.  The tutorial teaches a reader with zero assembly experience how every line of firmware works.

---

## Chapter Structure (30 Chapters)

### Group 1: Foundations (Chapters 1–6)

Generic computer-science fundamentals.  No code yet.

| Chapter | Topic |
|---------|-------|
| 1 | What Is a Computer |
| 2 | Number Systems — Binary, Hexadecimal, Decimal |
| 3 | Memory — Addresses, Bytes, Words, Endianness |
| 4 | What Is a Register |
| 5 | Load-Store Architecture |
| 6 | Fetch-Decode-Execute Cycle in Detail |

### Group 2: Instruction Set (Chapters 7–12)

ISA-specific deep dive.  Every instruction format, encoding, and behavior.

| Chapter | Topic |
|---------|-------|
| 7 | ISA Overview (e.g., rv32imac_zicsr or Cortex-M33 Thumb-2) |
| 8 | Immediate and Upper-Immediate Instructions |
| 9 | Arithmetic and Logic Instructions |
| 10 | Memory Access — Load and Store Deep Dive |
| 11 | Branch Instructions |
| 12 | Jumps, Calls, and Returns |

### Group 3: Assembly Programming (Chapters 13–17)

Practical assembly topics that apply to writing real firmware.

| Chapter | Topic |
|---------|-------|
| 13 | Pseudoinstructions |
| 14 | Assembler Directives |
| 15 | Calling Convention and Stack Frames |
| 16 | Bitwise Operations for Hardware Programming |
| 17 | Memory-Mapped I/O |

### Group 4: Hardware (Chapter 18)

Chip-specific architecture and block diagram.

| Chapter | Topic |
|---------|-------|
| 18 | The Microcontroller — Architecture and Hardware |

### Group 5: Build System (Chapters 19–20)

Toolchain, linker script, build pipeline.

| Chapter | Topic |
|---------|-------|
| 19 | The Linker Script — Placing Code in Memory |
| 20 | The Build Pipeline — From Assembly to Flashable Binary |

### Group 6: Source Code Walkthroughs (Chapters 21–29)

One chapter per source file (or logical unit).  Every single line explained.

| Chapter | Topic |
|---------|-------|
| 21 | Boot Metadata (image_def.s) |
| 22 | Constants File (constants.s) |
| 23 | Stack and Vector Table (stack.s, vector_table.s) |
| 24 | Boot Sequence / Reset Handler (reset_handler.s) |
| 25 | Oscillator Init (xosc.s) |
| 26 | Reset Controller (reset.s) |
| 27 | Peripheral Driver Part 1 — Init (e.g., uart.s init) |
| 28 | Peripheral Driver Part 2 — TX/RX (e.g., uart.s tx/rx) |
| 29 | Application Entry Point (main.s) |

### Group 7: Integration (Chapter 30)

Full build-flash-wire-test walkthrough.

| Chapter | Topic |
|---------|-------|
| 30 | Full Integration — Build, Flash, Wire, and Test |

---

## File Naming

- Each chapter is a separate Markdown file: `CHAPTER-01.md` through `CHAPTER-30.md`
- All chapters live in a `TUTORIAL/` subdirectory at the repo root
- Zero-padded two-digit numbers: `01`, `02`, ... `30`

---

## Markdown Formatting

### Headings

- `# Chapter N: Title` — one H1 per file, always line 1
- `## Section Title` — major sections within a chapter
- `### Subsection Title` — subsections as needed

### Introduction

Every chapter starts with an `## Introduction` section immediately after the H1.  This section sets context and states what the chapter covers.

### Code Blocks

- Use fenced code blocks with language tag: ` ```asm ` for assembly
- Indent code inside fenced blocks with **2 spaces** (matches the actual source files)
- Every code block must be immediately followed by a **line-by-line explanation**

### Tables

Use standard Markdown pipe tables for register maps, instruction summaries, and comparisons.

### Diagrams

- Use **plain ASCII art only** — no Unicode box-drawing characters (they render inconsistently)
- Use `+`, `-`, `|` for boxes
- Keep diagrams inside fenced code blocks (no language tag)

---

## Comment Alignment Rule

**This is the most critical formatting rule.**

All inline comments in assembly code blocks must have the `#` (RISC-V) or `//` (ARM) character starting at exactly **column 50** (1-indexed).

That means:
- 49 characters precede the comment character (0-indexed position 49)
- The comment character is the 50th character on the line
- Pad with spaces between the instruction and the comment to reach column 50
- If the code portion exceeds 49 characters, the comment still starts at column 50 — restructure the line or shorten it

### RISC-V Example (correct)

```
  li    t0, 0x40070000                           # load UART0 base address
  lw    t1, UARTFR(t0)                           # read UART flag register
  andi  t1, t1, UART_TXFF                        # isolate TX FIFO full flag
  bnez  t1, .Lwait_tx                            # loop if FIFO is full
```

The `#` is at column 50 on every line.

### ARM Example (correct)

```
  ldr   r0, =RESETS_RESET                        // load RESETS->RESET address
  ldr   r1, [r0]                                 // read RESETS->RESET value
  bic   r1, r1, #(1<<26)                         // clear UART0 reset bit
  str   r1, [r0]                                 // write value back
```

The `//` is at column 50 on every line.

### Verification

After writing or editing any chapter, run a scan across all chapter files to confirm every comment in every code block starts at column 50.  Fix any violations before considering the work done.

---

## Writing Style

### Tone

- Direct, declarative, authoritative
- No hedging ("this might", "you could perhaps")
- No fluff or filler — every sentence teaches something
- Write as if the reader is intelligent but has zero assembly knowledge

### Explanation Depth

- **Every single line of assembly must be explained** — what it does, why it's there, and what would happen if it were missing
- Explain bit manipulation with actual binary values
- Show register contents before and after operations
- Explain hardware behavior triggered by register writes

### Terminology

- Define every term on first use
- Use consistent terminology throughout all 30 chapters
- Reference previous chapters when building on earlier concepts: "As we saw in Chapter N..."

---

## README Integration

The repo README.md must include a `## Tutorial` section with:

1. All 30 chapters listed with links to their Markdown files
2. Grouped into the 7 groups above with group headings
3. Each chapter entry includes all `##` subheadings as sub-links
4. Links use relative paths: `TUTORIAL/CHAPTER-XX.md#anchor`
5. Anchors are lowercase, hyphenated versions of the heading text

---

## Adaptation for Different Architectures

When creating a book for a different architecture (e.g., ARM Cortex-M33 instead of RISC-V Hazard3):

1. **Chapters 1–6**: Mostly reusable — update any ISA-specific references
2. **Chapters 7–12**: Rewrite entirely for the target ISA (ARM Thumb-2, etc.)
3. **Chapters 13–17**: Update instruction examples but structure stays the same
4. **Chapter 18**: Rewrite for the specific chip (same chip may have different core)
5. **Chapters 19–20**: Update toolchain commands (e.g., `arm-none-eabi-as` vs `riscv32-unknown-elf-as`)
6. **Chapters 21–29**: Rewrite line-by-line walkthroughs for the actual source files
7. **Chapter 30**: Update build/flash/test procedure

### Comment Character

- RISC-V assembly: `#`
- ARM assembly: `//`
- Both must start at column 50

---

## Checklist Before Delivery

- [ ] 30 files exist: `CHAPTER-01.md` through `CHAPTER-30.md` in `TUTORIAL/`
- [ ] Every file starts with `# Chapter N: Title`
- [ ] Every file has an `## Introduction` section
- [ ] All assembly code blocks use 2-space indentation
- [ ] All inline comments start at column 50
- [ ] All diagrams use ASCII only (no Unicode box-drawing)
- [ ] README.md has Tutorial section with all chapters and subheading links
- [ ] Every line of assembly in walkthrough chapters is explained
- [ ] No orphan references to chapters that don't exist
