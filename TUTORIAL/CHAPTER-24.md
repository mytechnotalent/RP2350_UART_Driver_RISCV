# Chapter 24: reset_handler.s — The Boot Sequence Line by Line

## Introduction

`Reset_Handler` is the first function that runs after the boot ROM transfers control.  It calls every initialization routine in the correct order and then jumps to the main application loop.  This chapter walks through every line, explaining what it does and why the order matters.

## Full Source: reset_handler.s

```asm
.include "constants.s"

.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

.global Reset_Handler                            # export Reset_Handler symbol
.type Reset_Handler, @function
Reset_Handler:
  call  Init_Stack                               # initialize SP
  call  Init_Trap_Vector                         # install trap vector
  call  Init_XOSC                                # initialize external crystal oscillator
  call  Enable_XOSC_Peri_Clock                   # enable XOSC peripheral clock
  call  Init_Subsystem                           # initialize subsystems
  call  UART_Release_Reset                       # ensure UART0 out of reset
  call  UART_Init                                # initialize UART0 (pins, baud, enable)
  call  Enable_Coprocessor                       # no-op on RISC-V (kept for parity)
  j     main                                     # branch to main loop
.size Reset_Handler, . - Reset_Handler

.global Default_Trap_Handler
.type Default_Trap_Handler, @function
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap

.global Init_Trap_Vector
.type Init_Trap_Vector, @function
Init_Trap_Vector:
  la    t0, Default_Trap_Handler                 # trap target
  csrw  mtvec, t0                                # mtvec = trap entry
  ret                                            # return
```

## Section Setup

```asm
.include "constants.s"
```

Includes all `.equ` constant definitions.

```asm
.section .text
.align 2
```

Code goes in `.text`, 4-byte aligned.

```asm
.global Reset_Handler
.type Reset_Handler, @function
```

Exports `Reset_Handler` so the linker can resolve the reference in `image_def.s` (`.word Reset_Handler`) and `vector_table.s`.

## The Reset_Handler Function

### call Init_Stack

```asm
  call  Init_Stack                               # initialize SP
```

**Why first?**  Every subsequent `call` instruction uses the stack (it needs `ra` saved if the call chain goes deep, and function prologues may use `sp`).  Without a valid stack pointer, no function calls are safe.

After this line: `sp = 0x20082000`

### call Init_Trap_Vector

```asm
  call  Init_Trap_Vector                         # install trap vector
```

**Why second?**  If anything goes wrong during the remaining initialization (invalid address, misaligned access, illegal instruction), the CPU needs to know where to jump.  Setting up the trap vector ensures errors are caught rather than causing undefined behavior.

After this line: `mtvec` CSR points to `Default_Trap_Handler`.

### call Init_XOSC

```asm
  call  Init_XOSC                                # initialize external crystal oscillator
```

**Why third?**  The UART needs a precise clock for baud rate generation.  The crystal oscillator provides 12 MHz precision.  The internal ring oscillator (~6.5 MHz) is too imprecise and varies with temperature and voltage.

This function:
1. Writes startup delay to XOSC_STARTUP
2. Enables the crystal oscillator via XOSC_CTRL
3. Polls XOSC_STATUS bit 31 until the crystal is stable

After this line: XOSC is running at 12 MHz.

### call Enable_XOSC_Peri_Clock

```asm
  call  Enable_XOSC_Peri_Clock                   # enable XOSC peripheral clock
```

**Why fourth?**  Starting the XOSC is not enough — we must route it to the peripheral clock domain.  The UART hardware gets its timing reference from `clk_peri`, which must be connected to XOSC.

This function:
1. Reads CLK_PERI_CTRL register
2. Sets the enable bit (bit 11)
3. Sets AUXSRC to XOSC (bit 7)
4. Writes back

After this line: periperals have a 12 MHz clock derived from XOSC.

### call Init_Subsystem

```asm
  call  Init_Subsystem                           # initialize subsystems
```

**Why fifth?**  Before configuring GPIO pins, we must release IO_BANK0 from reset.  After power-on, IO_BANK0 is held in reset and its registers are inaccessible.

This function:
1. Clears bit 6 (IO_BANK0) in RESETS_RESET using read-modify-write
2. Polls RESETS_RESET_DONE bit 6 until done

After this line: IO_BANK0 is out of reset; GPIO control registers are accessible.

### call UART_Release_Reset

```asm
  call  UART_Release_Reset                       # ensure UART0 out of reset
```

**Why sixth?**  Same principle as IO_BANK0 — UART0 starts in reset.  We must release it before accessing any UART register.

This function:
1. Clears bit 26 (UART0) in RESETS_RESET using read-modify-write
2. Polls RESETS_RESET_DONE bit 26 until done

After this line: UART0 is out of reset; UART registers are accessible.

### call UART_Init

```asm
  call  UART_Init                                # initialize UART0 (pins, baud, enable)
```

**Why seventh?**  Now that both IO_BANK0 and UART0 are out of reset, and the peripheral clock is running from XOSC, we can safely configure the UART.

This function:
1. Sets GPIO0 FUNCSEL=2 (UART TX)
2. Sets GPIO1 FUNCSEL=2 (UART RX)
3. Configures GPIO0 pad for output
4. Configures GPIO1 pad for input
5. Disables UART (UARTCR = 0) before configuration
6. Sets baud rate (IBRD=6, FBRD=33 for 115200 baud)
7. Sets line control (8-bit, FIFO enabled)
8. Enables UART with TX and RX

After this line: UART0 is fully configured and ready to send/receive data at 115200 baud, 8N1.

### call Enable_Coprocessor

```asm
  call  Enable_Coprocessor                       # no-op on RISC-V (kept for parity)
```

On the ARM version of this firmware, this would enable the FPU coprocessor.  On RISC-V, this is a no-op `ret` — the function immediately returns.  It exists to maintain structural parity with the ARM codebase.

### j main

```asm
  j     main                                     # branch to main loop
```

An unconditional jump (not `call`) to the `main` function.  We use `j` instead of `call` because `main` contains an infinite loop and never returns.  There is no return address to save.

The `j` pseudoinstruction expands to `jal zero, main` — jump to main, discard return address (writes to zero).

**This is the point where initialization is complete and the application begins.**

### .size Directive

```asm
.size Reset_Handler, . - Reset_Handler
```

Records the function's size in the ELF symbol table.  `. - Reset_Handler` computes the distance from the current location to the Reset_Handler label.  This helps debuggers and disassemblers show function boundaries.

## Default_Trap_Handler

```asm
.global Default_Trap_Handler
.type Default_Trap_Handler, @function
Default_Trap_Handler:
  j     Default_Trap_Handler                     # lock here on unexpected trap
```

An infinite loop.  If the CPU encounters any exception (illegal instruction, misaligned access, external interrupt), `mtvec` sends it here.  The infinite loop ensures the processor does not continue executing garbage — it freezes, which is safer than undefined behavior.

In a production system, you might:
- Read `mcause` CSR to identify what went wrong
- Read `mepc` CSR to identify where it happened
- Log the error or flash an LED

For our minimal firmware, the infinite loop is sufficient.

## Init_Trap_Vector

```asm
.global Init_Trap_Vector
.type Init_Trap_Vector, @function
Init_Trap_Vector:
  la    t0, Default_Trap_Handler                 # trap target
  csrw  mtvec, t0                                # mtvec = trap entry
  ret                                            # return
```

### Line: la t0, Default_Trap_Handler

```asm
  la    t0, Default_Trap_Handler                 # trap target
```

Loads the address of `Default_Trap_Handler` into `t0`.  The `la` pseudoinstruction expands to `lui t0, upper20` + `addi t0, t0, lower12` (or `auipc` + `addi` for PIC).

### Line: csrw mtvec, t0

```asm
  csrw  mtvec, t0                                # mtvec = trap entry
```

Writes the handler address to the `mtvec` (Machine Trap Vector Base Address) CSR.  

`csrw` is a pseudoinstruction that expands to `csrrw zero, mtvec, t0` — write `t0` to CSR `mtvec`, discard the old value (written to zero).

The lower bits of `mtvec` specify the mode:
- Bits [1:0] = 0: Direct mode (all traps go to the same address)
- Bits [1:0] = 1: Vectored mode (traps go to base + 4×cause)

Since our handler address is 4-byte aligned, bits [1:0] are 00 = direct mode.  All traps go to `Default_Trap_Handler`.

### Line: ret

```asm
  ret                                            # return
```

Returns to `Reset_Handler`.  `Init_Trap_Vector` is a leaf function — it does not call any other function, so `ra` is unchanged and `ret` safely returns.

## The Complete Initialization Order

```
  1. Init_Stack           → sp = 0x20082000
  2. Init_Trap_Vector     → mtvec = Default_Trap_Handler
  3. Init_XOSC            → 12 MHz crystal running
  4. Enable_XOSC_Peri_Clock → clk_peri sourced from XOSC
  5. Init_Subsystem        → IO_BANK0 out of reset
  6. UART_Release_Reset    → UART0 out of reset
  7. UART_Init             → UART0 configured for 115200 8N1
  8. Enable_Coprocessor    → no-op on RISC-V
  9. j main               → application starts
```

**This order is not arbitrary.  Changing it would cause failures:**
- Moving Init_XOSC before Init_Stack → stack invalid during XOSC polling
- Moving UART_Init before Init_Subsystem → GPIO registers inaccessible
- Moving UART_Init before UART_Release_Reset → UART registers inaccessible
- Moving Enable_XOSC_Peri_Clock before Init_XOSC → no XOSC to route

## Practice Problems

1. Why is `j main` used instead of `call main`?
2. What happens if Init_Stack is not called first?
3. What CSR does Init_Trap_Vector write to?
4. What happens when an illegal instruction executes?
5. Could you swap Init_XOSC and Init_Trap_Vector? Why or why not?

### Answers

1. Because `main` never returns (infinite loop), so saving a return address is unnecessary.
2. `sp` is undefined; `call` instructions write `ra` which works, but any function using the stack would access random memory.
3. `mtvec` (Machine Trap Vector Base Address)
4. The CPU traps to the address in `mtvec`, which points to `Default_Trap_Handler`, which loops infinitely.
5. Yes, you could. Init_Trap_Vector does not need the XOSC, and Init_XOSC does not depend on the trap vector. However, it is good practice to set up the trap vector early so any error during XOSC init is caught.

## Chapter Summary

`Reset_Handler` is the firmware entry point.  It calls eight initialization functions in a carefully ordered sequence: stack, trap vector, crystal oscillator, peripheral clock, I/O bank reset, UART reset, UART configuration, and coprocessor stub.  Then it jumps to `main`.  `Default_Trap_Handler` provides a safe infinite loop for any exception.  `Init_Trap_Vector` programs the mtvec CSR to point to this handler.  The initialization order is critical — each step depends on previous steps having completed.
