# Chapter 15: The Calling Convention and Stack Frames

## Introduction

When one function calls another, both functions share the same 32 registers.  Without rules, the called function could destroy values the caller still needs.  The **calling convention** is a set of rules that prevents this chaos.  Every function in our firmware follows these rules.

## The RISC-V ilp32 Calling Convention

### Argument Passing

Arguments are passed in registers `a0` through `a7` (x10-x17):
- First argument → `a0`
- Second argument → `a1`
- ...up to 8 arguments in registers
- Additional arguments go on the stack (rare in embedded)

### Return Values

Return values use `a0` and `a1`:
- Single 32-bit return → `a0`
- 64-bit return → `a0` (low), `a1` (high)

### Register Preservation Rules

| Category | Registers | Rule |
|---|---|---|
| Caller-saved | t0-t6, a0-a7, ra | Callee may overwrite freely |
| Callee-saved | s0-s11, sp | Callee must save on entry and restore on exit |
| Special | zero | Always 0 |
| Special | gp, tp | Reserved, not used in our firmware |

**Caller-saved** means: if you need the value after a call, YOU (the caller) must save it.

**Callee-saved** means: the called function guarantees these registers have the same value when it returns as when it was called.

## The Stack

The stack is a region of memory used for:
1. Saving register values (caller-saved or callee-saved preservation)
2. Local variables that do not fit in registers
3. Passing extra arguments beyond a0-a7

### Stack Growth Direction

On RISC-V, the stack grows **downward** — from high addresses toward low addresses.

```
  High address:  0x20082000 ← STACK_TOP (initial sp)
                 0x2008_1FFC ← first push
                 0x2008_1FF8 ← second push
                 ...
  Low address:   0x2007A000 ← STACK_LIMIT
```

The `sp` register always points to the last used (lowest) stack location.

### Stack Operations

RISC-V has no dedicated push/pop instructions.  Stack operations are explicit:

**Push (allocate and save):**
```asm
  addi  sp, sp, -16                              # allocate 16 bytes (grow stack down)
  sw    ra, 12(sp)                               # save ra at sp+12
  sw    s0, 8(sp)                                # save s0 at sp+8
  sw    s1, 4(sp)                                # save s1 at sp+4
  sw    s2, 0(sp)                                # save s2 at sp+0
```

**Pop (restore and deallocate):**
```asm
  lw    ra, 12(sp)                               # restore ra from sp+12
  lw    s0, 8(sp)                                # restore s0 from sp+8
  lw    s1, 4(sp)                                # restore s1 from sp+4
  lw    s2, 0(sp)                                # restore s2 from sp+0
  addi  sp, sp, 16                               # deallocate 16 bytes (shrink stack up)
```

### Stack Alignment

The RISC-V calling convention requires `sp` to be 16-byte aligned at function entry.  Always allocate stack space in multiples of 16.

## Stack Frame Layout

A function's stack frame is the block of memory between the caller's `sp` and the callee's adjusted `sp`:

```
  ┌─────────────────────┐ ← caller's sp (before call)
  │   (caller's frame)  │
  ├─────────────────────┤ ← sp on entry = sp after callee adjusts + frame_size
  │   saved ra          │ sp + 12
  │   saved s0          │ sp + 8
  │   saved s1          │ sp + 4
  │   local variables   │ sp + 0
  └─────────────────────┘ ← sp (callee's adjusted sp)
```

## Function Types in Our Firmware

### Leaf Functions (No Calls to Other Functions)

A leaf function does not call any other function.  Therefore, `ra` is never overwritten and does not need saving.

Most functions in our firmware are leaf functions:

```asm
Init_Stack:                                      # leaf function
  li    sp, STACK_TOP                            # only uses sp, no calls
  ret                                            # ra is untouched, safe to return
```

```asm
Init_Trap_Vector:                                # leaf function
  la    t0, Default_Trap_Handler                 # uses t0 (caller-saved, OK)
  csrw  mtvec, t0                                # CSR write
  ret                                            # ra untouched
```

Leaf functions:
- Do NOT save `ra` (it was not modified)
- Do NOT adjust `sp` (no stack frame needed)
- Use only temporary registers (t0-t6) and argument registers (a0-a7)
- Are the simplest and most common type

### Non-Leaf Functions (Call Other Functions)

A non-leaf function calls other functions, which means `ra` gets overwritten.  It must save `ra`.

`Reset_Handler` is technically a non-leaf function — it calls many subroutines.  However, it never returns (it jumps to `main`), so saving `ra` is unnecessary.

If `Reset_Handler` needed to return, it would look like:

```asm
Reset_Handler:
  addi  sp, sp, -16                              # allocate stack frame
  sw    ra, 12(sp)                               # save return address
  call  Init_Stack                               # ra overwritten
  call  Init_XOSC                                # ra overwritten again
  # ... more calls ...
  lw    ra, 12(sp)                               # restore original return address
  addi  sp, sp, 16                               # deallocate stack frame
  ret                                            # return to actual caller
```

## How Arguments Flow in Our Firmware

### UART0_Out

```asm
  # In main.s:
  call  UART0_In                                 # returns character in a0
  call  UART0_Out                                # expects character in a0

  # The return value of UART0_In (in a0) becomes the argument to UART0_Out (in a0)
  # No extra move needed because both use a0!
```

### UART0_In

```asm
UART0_In:
  li    t0, UART0_BASE                           # t0 = UART base (temporary)
.Lwait_rx:
  lw    t1, UARTFR(t0)                           # t1 = flags (temporary)
  andi  t1, t1, UART_RXFE                        # test RX empty bit
  bnez  t1, .Lwait_rx                            # loop if empty
  lw    a0, UARTDR(t0)                           # a0 = received byte (return value)
  ret
```

- Uses `t0`, `t1` — temporaries, no saving needed
- Returns in `a0` — convention for return value
- Leaf function — no stack frame

### UART0_Out

```asm
UART0_Out:
  li    t0, UART0_BASE                           # t0 = UART base
.Lwait_tx:
  lw    t1, UARTFR(t0)                           # t1 = flags
  andi  t1, t1, UART_TXFF                        # test TX full bit
  bnez  t1, .Lwait_tx                            # loop if full
  sw    a0, UARTDR(t0)                           # transmit byte from a0 (argument)
  ret
```

- Takes argument in `a0` — the byte to transmit
- Uses `t0`, `t1` — temporaries
- Leaf function — no stack frame

## Caller-Saved in Action

The `main` loop:

```asm
.Loop:
  call  UART0_In                                 # a0 = received character
  call  UART0_Out                                # send a0 (could clobber t0-t6)
  j     .Loop                                    # loop forever
```

Between the two calls, `a0` holds the character.  `UART0_In` returns it; `UART0_Out` consumes it.  Since `a0` is caller-saved and `UART0_Out` uses it as input, this works perfectly.

But what if we needed to use the character AFTER calling `UART0_Out`?  We would need to save it:

```asm
  call  UART0_In                                 # a0 = character
  mv    s0, a0                                   # save in callee-saved register
  call  UART0_Out                                # may clobber a0
  # s0 still holds the character (callee-saved guarantee)
```

But then `s0` must be saved to the stack by any function that uses it.

## Practice Problems

1. Where does the first argument to a function go?
2. What must a function do if it uses register `s0`?
3. Why does `Init_Stack` not need a stack frame?
4. What is the minimum stack frame size (alignment requirement)?
5. If function A calls B which calls C, which function saves `ra`?

### Answers

1. Register `a0` (x10)
2. Save `s0` to the stack on entry and restore it before returning (callee-saved).
3. It is a leaf function that only uses `sp` (which it sets, not preserves) and returns via `ra` (which it does not modify).
4. 16 bytes (sp must be 16-byte aligned).
5. Both A and B must save `ra` if they need to return after calling the next function.  C is a leaf; it does not save `ra` unless it calls something else.

## Chapter Summary

The calling convention defines rules for register usage: a0-a7 for arguments, a0-a1 for returns, t0-t6 are caller-saved, s0-s11 are callee-saved.  The stack grows downward; sp must be 16-byte aligned.  Leaf functions need no stack frame.  Non-leaf functions must save ra.  Our firmware uses only leaf functions called from Reset_Handler and main, keeping the calling convention overhead minimal.
