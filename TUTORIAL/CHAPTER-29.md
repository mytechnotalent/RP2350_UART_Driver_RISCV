# Chapter 29: main.s — The Application Entry Point

## Introduction

After nine initialization functions execute in `Reset_Handler`, the firmware jumps to `main`.  This chapter examines every line of the main application file — the infinite echo loop, the unreachable return, and the empty data sections.

## Full Source: main.s

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global main                                     # export main
.type main, @function                            # mark as function
main:
.Loop:
  call  UART0_In                                 # call UART0_In
  call  UART0_Out                                # call UART0_Out
  j     .Loop                                    # loop forever
  ret                                            # return to caller

.section .rodata                                 # read-only data section

.section .data                                   # data section

.section .bss                                    # BSS section
```

## The .text Section

```asm
.include "constants.s"
```

Includes all constant definitions.  While `main.s` does not directly use any constants (no `li` with named constants), the include is present for consistency and in case constants are needed in the future.

```asm
.section .text                                   # code section
.align 2                                         # align to 4-byte boundary
```

Standard preamble: code in `.text`, 4-byte aligned.

```asm
.global main                                     # export main
.type main, @function                            # mark as function
```

Exports `main` so the linker resolves the `j main` in `reset_handler.s`.

## The Echo Loop

```asm
main:
.Loop:
```

Two labels at the same address.  `main` is the function entry point.  `.Loop` is a local label for the loop jump target.

### Step 1: Receive a Byte

```asm
  call  UART0_In                                 # call UART0_In
```

`call` is a pseudoinstruction for `auipc ra, offset[31:12]` + `jalr ra, ra, offset[11:0]`.  It:
1. Saves the return address (address of next instruction) in `ra`
2. Jumps to `UART0_In`

`UART0_In` blocks (busy-waits) until a byte arrives on the RX pin.  When it returns:
- `a0` = received byte (8 bits, 0x00–0xFF)
- `ra` = address of the next instruction (`call UART0_Out`)

### Step 2: Transmit the Same Byte

```asm
  call  UART0_Out                                # call UART0_Out
```

Calls `UART0_Out` with the byte still in `a0` (UART0_In left it there, and no instruction between the two calls modifies `a0`).

`UART0_Out` blocks until the TX FIFO has space, then writes `a0` to UARTDR.  After return:
- The byte is in the TX FIFO, being serialized out on GPIO0
- `a0` still contains the byte value (UART0_Out does not clear it)
- `ra` = address of the next instruction (`j .Loop`)

### Step 3: Loop Forever

```asm
  j     .Loop                                    # loop forever
```

Unconditional jump back to `.Loop`.  Expands to `jal zero, .Loop` — jumps and discards the return address (writes to `x0`).

This creates an infinite loop:
```
  → UART0_In (wait for byte)
  → UART0_Out (echo byte back)
  → jump back to UART0_In
  → UART0_In (wait for next byte)
  → ...
```

**The firmware runs forever.**  There is no exit condition, no shutdown sequence.  The loop only stops when power is removed or the chip is reset.

### The Unreachable ret

```asm
  ret                                            # return to caller
```

This instruction is **never executed** because the `j .Loop` above it creates an infinite loop.  It exists as a structural convention — every function has a `ret` at the end.  A disassembler or debugger showing the function boundary sees a clean function epilogue.

If for some reason the `j` instruction were removed or skipped (impossible in normal operation), `ret` would try to return to whatever address is in `ra`.  Since `Reset_Handler` used `j main` (not `call main`), `ra` was not set to a return address, and `ret` would jump to whatever `ra` happened to contain from the last `call` instruction within the loop.

## The Data Sections

```asm
.section .rodata                                 # read-only data section

.section .data                                   # data section

.section .bss                                    # BSS section
```

Three empty sections.  They generate zero bytes in the binary.  They are declared as placeholders for future use:

| Section | Purpose | Example use |
|---|---|---|
| `.rodata` | Read-only constant data | String literals, lookup tables |
| `.data` | Initialized global variables | `message: .asciz "Hello\n"` |
| `.bss` | Uninitialized global variables | `buffer: .space 64` |

In the linker script, `.rodata` is placed alongside `.text` in flash (read-only).  `.data` and `.bss` would be placed in RAM.

## Register Usage Throughout the Loop

Let us trace register state through one complete loop iteration:

```
  State at .Loop entry:
    a0 = undefined (first iteration) or previous byte
    ra = varies
    sp = 0x20082000

  After call UART0_In:
    a0 = received byte (e.g., 0x41 for 'A')
    ra = address of "call UART0_Out" instruction
    t0 = UART0_BASE (from UART0_In internals)
    t1 = modified (from UART0_In internals)

  After call UART0_Out:
    a0 = same byte (0x41), masked to 8 bits
    ra = address of "j .Loop" instruction
    t0 = UART0_BASE (from UART0_Out internals)
    t1 = modified (from UART0_Out internals)

  After j .Loop:
    All registers unchanged, PC = .Loop address
```

Key observation: `a0` flows directly from `UART0_In` to `UART0_Out` without modification.  This is the calling convention at work — return values go in `a0`, and the first parameter is also `a0`.

## Why This Code Is Minimal

The entire application is 4 instructions:
```asm
  call  UART0_In                                 # 8 bytes (auipc + jalr)
  call  UART0_Out                                # 8 bytes (auipc + jalr)
  j     .Loop                                    # 4 bytes (jal zero)
  ret                                            # 4 bytes (jalr zero, ra) (unreachable)
```

Total: 24 bytes of machine code for the application logic.  The entire firmware (including all initialization) is well under 1 KB.

This minimalism is a feature, not a limitation.  Bare-metal firmware should be as small as possible, doing exactly what is needed and nothing more.

## Complete Execution Timeline

From power-on to first echo:

```
  0.000 ms   Power on, boot ROM starts
  ~50 ms     Boot ROM scans flash, finds IMAGE_DEF
  ~50 ms     Boot ROM sets PC = Reset_Handler
  ~50 ms     Init_Stack: sp = 0x20082000
  ~50 ms     Init_Trap_Vector: mtvec = Default_Trap_Handler
  ~58 ms     Init_XOSC: crystal starts, stabilizes (~8 ms)
  ~58 ms     Enable_XOSC_Peri_Clock: clk_peri = XOSC
  ~58 ms     Init_Subsystem: IO_BANK0 out of reset
  ~58 ms     UART_Release_Reset: UART0 out of reset
  ~58 ms     UART_Init: GPIO configured, baud set, UART enabled
  ~58 ms     Enable_Coprocessor: no-op
  ~58 ms     j main: enter application
  ~58 ms     UART0_In: begin polling RX FIFO...
  ???  ms    User types a character
  +0.087 ms  UART0_Out: character echoed back
  +0.087 ms  j .Loop: wait for next character
```

Most of the startup time is the crystal oscillator stabilizing.  Once in the main loop, the firmware responds within microseconds of receiving data.

## Practice Problems

1. How many machine code bytes does the main loop consume?
2. What register passes data from UART0_In to UART0_Out?
3. Is the `ret` at the end ever executed?
4. Why is `j main` used in reset_handler.s instead of `call main`?
5. What do the empty .rodata, .data, and .bss sections generate?

### Answers

1. 20 bytes (two `call` = 8 bytes each, one `j` = 4 bytes). The unreachable `ret` adds 4 more for a total of 24 bytes in the function.
2. `a0` — UART0_In returns the byte in `a0`, and UART0_Out reads its parameter from `a0`.
3. No. The `j .Loop` instruction always jumps back before `ret` can execute.
4. Because `main` contains an infinite loop and never returns. Using `j` avoids unnecessarily overwriting `ra` with a return address that would never be used.
5. Zero bytes. Empty section declarations generate no data in the binary.

## Chapter Summary

`main.s` contains a three-instruction infinite loop: `call UART0_In` to receive a byte into `a0`, `call UART0_Out` to transmit that same byte, and `j .Loop` to repeat.  The received byte flows from one function to the next through register `a0`, exploiting the RISC-V calling convention.  The unreachable `ret` and empty data sections are structural conventions.  The entire application is 24 bytes of machine code.
