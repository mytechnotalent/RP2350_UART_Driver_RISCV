# Chapter 17: Memory-Mapped I/O — Controlling Hardware Through Addresses

## Introduction

Chapters 3 and 5 introduced the concept of memory-mapped I/O.  This chapter goes deeper, explaining exactly how hardware peripherals appear as memory addresses, how the bus fabric routes transactions, and the specific rules that govern peripheral register access on RP2350.

## The Principle

In memory-mapped I/O, peripheral hardware registers are assigned addresses in the CPU's address space.  The CPU uses the same `lw` and `sw` instructions to access both RAM and peripheral registers.  The bus fabric (interconnect) examines the address and routes the transaction to the correct destination.

```
  CPU executes: sw t1, 0x00(t0)     where t0 = 0x40070000

  1. CPU places address 0x40070000 on the address bus
  2. CPU places value of t1 on the data bus
  3. CPU asserts WRITE signal
  4. Bus fabric sees address 0x4xxxxxxx → routes to APB peripheral bus
  5. APB bus decodes 0x40070xxx → UART0 block
  6. UART0 block decodes offset 0x000 → UARTDR (data register)
  7. UART0 hardware accepts the byte and begins serial transmission
```

From the CPU's perspective, this was just a store instruction.  The magic happens in the bus fabric and peripheral hardware.

## RP2350 Address Space Map

```
  0x00000000 ┬─────────────────────────┐
             │ Boot ROM                │  16 KB
  0x10000000 ├─────────────────────────┤
             │ Flash (XIP window)      │  32 MB
  0x12000000 ├─────────────────────────┤
             │ (unused)                │
  0x20000000 ├─────────────────────────┤
             │ SRAM                    │  520 KB
  0x20082000 ├─────────────────────────┤
             │ (unused)                │
  0x40000000 ├─────────────────────────┤
             │ APB Peripherals         │  UART, SPI, I2C, GPIO, etc.
  0x50000000 ├─────────────────────────┤
             │ AHB Peripherals         │  DMA, USB, PIO, etc.
  0xE0000000 ├─────────────────────────┤
             │ Private Peripheral Bus  │  SysTick, NVIC, debug
  0xFFFFFFFF ┴─────────────────────────┘
```

## Peripheral Register Structure

Each peripheral block occupies a contiguous range of addresses.  Within that range, individual registers sit at fixed offsets:

### UART0 Block (Base: 0x40070000)

| Offset | Register | Description |
|---:|---|---|
| 0x00 | UARTDR | Data register (read = RX, write = TX) |
| 0x04 | UARTRSR | Receive status / error clear |
| 0x18 | UARTFR | Flag register (status bits) |
| 0x20 | UARTILPR | IrDA low-power counter |
| 0x24 | UARTIBRD | Integer baud rate divisor |
| 0x28 | UARTFBRD | Fractional baud rate divisor |
| 0x2C | UARTLCR_H | Line control (word length, parity, FIFO) |
| 0x30 | UARTCR | Control register (enable, TX/RX enable) |

### RESETS Block (Base: 0x40020000)

| Offset | Register | Description |
|---:|---|---|
| 0x00 | RESETS_RESET | Reset control (1 = held in reset) |
| 0x04 | RESETS_WDSEL | Watchdog select |
| 0x08 | RESETS_RESET_DONE | Reset done status (1 = out of reset) |

### XOSC Block (Base: 0x40048000)

| Offset | Register | Description |
|---:|---|---|
| 0x00 | XOSC_CTRL | Crystal oscillator control |
| 0x04 | XOSC_STATUS | Status (bit 31 = stable) |
| 0x0C | XOSC_STARTUP | Startup delay configuration |

## Register Types

Not all registers behave like RAM.  Peripheral registers have special behaviors:

### Read-Only (RO)

Writing has no effect.  Example: RESETS_RESET_DONE — you read it to check status but cannot write to it.

### Write-Only (WO)

Reading returns 0 or undefined.  Some control registers are write-only.

### Read-Write (RW)

Normal read and write.  Example: UARTCR — you can read the current setting and write a new one.

### Read-to-Clear

Reading the register clears it.  Example: some interrupt status registers.

### Write-to-Clear (W1C)

Writing a 1 to a bit clears that bit.  Writing 0 has no effect.

### Side-Effect on Read

Reading triggers hardware action.  Example: UARTDR — reading pops a byte from the RX FIFO.

### Side-Effect on Write

Writing triggers hardware action.  Example: UARTDR — writing pushes a byte to the TX FIFO.

## Volatility

Peripheral registers are **volatile** — their values can change at any time due to hardware events.  This means:
- You cannot assume a value read once will be the same next time
- The compiler (or your mental model in assembly) must not optimize away reads
- Polling loops must actually re-read the register each iteration

In assembly, this is automatic — `lw` always performs the memory access.  In C, you would mark peripheral pointers as `volatile`.

## Why Order Matters

Some hardware requires register writes in a specific order.  For example, UART initialization:

1. Disable UART first (UARTCR = 0)
2. Set baud rate (UARTIBRD, UARTFBRD)
3. Set line control (UARTLCR_H)
4. Enable UART last (UARTCR with enable bits)

Writing out of order may cause undefined behavior or corrupt the data path.

## The PPB (Private Peripheral Bus)

Some RISC-V system registers are accessed through memory-mapped addresses in the PPB region (0xE0000000 range).  However, on our Hazard3 core, system configuration is primarily done through CSRs, not memory-mapped PPB registers.

Our firmware defines:
```asm
  .equ PPB_BASE, 0xE0000000
```

But does not use it because we use `csrw mtvec, t0` instead of memory-mapped configuration.

## Atomic Access Concerns

On RP2350, single `lw`/`sw` instructions to peripheral registers are atomic at the bus level (the peripheral sees a complete 32-bit transaction).  However, read-modify-write sequences are NOT atomic:

```asm
  lw    t1, 0(t0)                                # read
  # ← an interrupt could fire here and modify the register
  ori   t1, t1, mask                             # modify
  sw    t1, 0(t0)                                # write (may overwrite interrupt's changes)
```

For our single-core, interrupt-disabled firmware, this is not an issue.  In more complex systems, you would disable interrupts around RMW sequences or use atomic operations.

## Practice Problems

1. What address is the UART0 flag register?
2. If you read UARTDR and get 0x41, what happened at the hardware level?
3. Why must you disable UART before changing baud rate settings?
4. What is the difference between reading SRAM at 0x20000000 and reading UARTFR at 0x40070018?
5. Why is a read-modify-write not atomic?

### Answers

1. 0x40070000 + 0x18 = 0x40070018
2. The UART hardware popped byte 0x41 ('A') from the receive FIFO and placed it on the data bus.
3. The data sheet specifies this sequence.  Changing baud rate while UART is active could corrupt in-flight data.
4. From the CPU's instruction perspective, identical (`lw`).  But SRAM returns stored data, while UARTFR returns live hardware status that changes with UART state.
5. Because it consists of multiple instructions.  Between the load and the store, another event (interrupt, DMA) could modify the register.

## Chapter Summary

Memory-mapped I/O maps peripheral hardware registers to addresses the CPU accesses with normal load/store instructions.  The bus fabric routes transactions based on address ranges.  Peripheral registers have special behaviors (read-only, write-to-clear, side effects).  Register values are volatile and can change at any time.  Access order matters for correct hardware initialization.  Single accesses are atomic; read-modify-write sequences are not.
