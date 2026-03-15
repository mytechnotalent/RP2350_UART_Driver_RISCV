# Chapter 12: RISC-V Jumps, Calls, and Returns

## Introduction

Branches handle conditional flow.  Jumps handle unconditional flow: calling subroutines, returning from them, and creating infinite loops.  This chapter covers every jump instruction and how function calls work at the machine level.

## JAL: Jump and Link

```asm
  jal   rd, offset                               # rd = PC + 4; PC = PC + offset
```

JAL does two things simultaneously:
1. Saves the return address (PC + 4) into register `rd`
2. Jumps to PC + sign-extended offset

The offset is 21 bits (J-type encoding), giving a range of ±1 MiB.

### J-Type Encoding

```
  [imm[20|10:1|11|19:12] | rd | opcode=1101111]
```

The immediate bits are scrambled (like B-type) but reassembled by hardware.

### Common Usage: Unconditional Jump

```asm
  jal   zero, label                              # jump to label, discard return address
```

Writing the return address to `zero` discards it (x0 ignores writes).  This is a pure unconditional jump.

The pseudoinstruction `j label` expands to `jal zero, label`:

```asm
  j     .Loop                                    # infinite loop (from main.s)
```

### Common Usage: Function Call

```asm
  jal   ra, function                             # ra = return address; jump to function
```

This saves the return address in `ra` so the called function can return.

## JALR: Jump and Link Register

```asm
  jalr  rd, rs1, offset                          # rd = PC + 4; PC = (rs1 + offset) & ~1
```

JALR jumps to the address computed from a register plus offset.  The lowest bit is cleared (set to 0) to ensure alignment.

### Common Usage: Return from Function

```asm
  jalr  zero, ra, 0                              # PC = ra; discard return address
```

The pseudoinstruction `ret` expands to exactly this:

```asm
  ret                                            # same as: jalr zero, ra, 0
```

This reads the return address from `ra`, jumps to it, and discards the "new return address" (written to zero).

### Common Usage: Indirect Jump

```asm
  jalr  zero, t0, 0                              # jump to address in t0
```

This allows jumping to a computed address (function pointers, jump tables).

## CALL Pseudoinstruction

The `call` pseudoinstruction combines two instructions:

```asm
  call  target                                   # call a function by name
```

Expands to:
```asm
  auipc ra, offset_hi                            # ra = PC + (upper 20 bits of offset)
  jalr  ra, ra, offset_lo                        # ra = PC+4; jump to ra + lower 12 bits
```

Why two instructions?  Because the target function might be more than ±1 MiB away (beyond JAL's 21-bit range).  AUIPC + JALR together can reach any address in the 32-bit space.

In practice, the assembler/linker resolves the actual offsets.  You just write `call function_name`.

## RET Pseudoinstruction

```asm
  ret                                            # return from function
```

Expands to:
```asm
  jalr  zero, ra, 0                              # jump to address in ra
```

## TAIL Pseudoinstruction

```asm
  tail  target                                   # tail call (jump without saving return address)
```

Expands to:
```asm
  auipc t1, offset_hi                            # t1 = PC + upper offset
  jalr  zero, t1, offset_lo                      # jump to target (no link)
```

Used for tail-call optimization: if the last thing a function does is call another function, it can jump directly without saving a return address.

## Function Call Mechanics Step by Step

Let us trace the exact sequence when `Reset_Handler` calls `Init_Stack`:

### Before the call

```
  PC = address of "call Init_Stack" in reset_handler.s
  ra = whatever (undefined at this point)
  sp = whatever (undefined, that's why we are calling Init_Stack)
```

### AUIPC executes

```asm
  auipc ra, offset_hi                            # ra = PC + upper bits of offset to Init_Stack
```

```
  ra = PC + (offset_hi << 12)
  PC = PC + 4
```

### JALR executes

```asm
  jalr  ra, ra, offset_lo                        # save return address, jump
```

```
  temp = ra + offset_lo       (this is the address of Init_Stack)
  ra = PC + 4                 (this is the return address: instruction after call)
  PC = temp & ~1              (jump to Init_Stack)
```

### Inside Init_Stack

```asm
  li    sp, STACK_TOP                            # set up the stack pointer
  ret                                            # return to caller
```

### RET executes

```asm
  jalr  zero, ra, 0                              # PC = ra (return to Reset_Handler)
```

```
  PC = ra                     (back to instruction after "call Init_Stack")
  zero = old PC + 4           (discarded)
```

### After return

Execution continues with the next instruction in `Reset_Handler`.

## The Complete Call Chain in Our Firmware

```
  Reset_Handler
    ├── call Init_Stack          → stack.s → ret
    ├── call Init_Trap_Vector    → reset_handler.s → ret
    ├── call Init_XOSC           → xosc.s → ret
    ├── call Enable_XOSC_Peri_Clock → xosc.s → ret
    ├── call Init_Subsystem      → reset.s → ret
    ├── call UART_Release_Reset  → uart.s → ret
    ├── call UART_Init           → uart.s → ret
    ├── call Enable_Coprocessor  → coprocessor.s → ret
    └── j    main                → main.s (never returns)
          └── .Loop:
                ├── call UART0_In   → uart.s → ret
                ├── call UART0_Out  → uart.s → ret
                └── j    .Loop      (infinite loop)
```

Notice that `Reset_Handler` uses `j main` (jump) instead of `call main`.  This is because `main` never returns — it runs an infinite loop.  There is no need to save a return address.

Also notice that every `call` is followed eventually by `ret`.  This is the function call/return discipline.

## Infinite Loops

An infinite loop is simply an unconditional jump to itself:

```asm
  j     .Loop                                    # branch back to .Loop forever
```

This is used in two places in our firmware:
1. `main.s` — the echo loop that runs forever
2. `reset_handler.s` — the `Default_Trap_Handler` that halts on exceptions

```asm
Default_Trap_Handler:
  j     Default_Trap_Handler                     # infinite loop on exception
```

## Nested Calls and the Stack

What happens if a function calls another function?  The second `call` overwrites `ra`.  The original return address is lost.

Solution: save `ra` to the stack before calling, and restore it after:

```asm
my_function:
  addi  sp, sp, -4                               # allocate 4 bytes on stack
  sw    ra, 0(sp)                                # save return address
  call  other_function                           # this overwrites ra
  lw    ra, 0(sp)                                # restore original return address
  addi  sp, sp, 4                                # deallocate stack space
  ret                                            # return to original caller
```

Our firmware avoids this because its call chain is only one level deep (Reset_Handler calls leaf functions that do not themselves call other functions).

## Practice Problems

1. What two things does `jal ra, target` do?
2. What does `ret` expand to?
3. Why does `j label` write the return address to zero?
4. Why does `Reset_Handler` use `j main` instead of `call main`?
5. If function A calls function B which calls function C, what must function B do with `ra`?

### Answers

1. Saves PC+4 into `ra` (return address) and jumps to `target`.
2. `jalr zero, ra, 0`
3. Because `j` is an unconditional jump that does not need a return address.  Writing to zero discards it.
4. Because `main` never returns (infinite loop), so saving a return address is pointless.
5. Function B must save `ra` to the stack before calling C, and restore it before returning to A.

## Chapter Summary

JAL jumps to a PC-relative target and links (saves return address).  JALR jumps to a register-computed address and links.  `call` uses AUIPC+JALR to reach any address.  `ret` uses JALR to return via `ra`.  `j` uses JAL with zero as the link register for unconditional jumps.  Function calls save the return address in `ra`; nested calls must save `ra` to the stack.
