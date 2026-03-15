<img src="https://github.com/mytechnotalent/RP2350_UART_Driver_RISCV/blob/main/RP2350_UART_Driver_RISCV.png?raw=true">

## FREE Embedded Hacking Course [HERE](https://github.com/mytechnotalent/Embedded-Hacking)
### VIDEO PROMO [HERE](https://www.youtube.com/watch?v=aD7X9sXirF8)

<br>

# RP2350 UART Driver RISC-V
An RP2350 UART driver written entirely in RISC-V Assembler.

<br>

# Install RISC-V Toolchain (Windows / RP2350 Hazard3)
Official Raspberry Pi guidance for RP2350 RISC-V points to pico-sdk-tools prebuilt releases.

## Official References
- RP2350 RISC-V quick start in pico-sdk: [HERE](https://github.com/raspberrypi/pico-sdk#risc-v-support-on-rp2350)
- Tool downloads (official): [HERE](https://github.com/raspberrypi/pico-sdk-tools/releases/tag/v2.0.0-5)

## Install (PowerShell)
```powershell
$url = "https://github.com/raspberrypi/pico-sdk-tools/releases/download/v2.0.0-5/riscv-toolchain-14-x64-win.zip"
$zipPath = "$env:TEMP\riscv-toolchain-14-x64-win.zip"
$dest = "$HOME\riscv-toolchain-14"

Invoke-WebRequest -Uri $url -OutFile $zipPath
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
Get-ChildItem -Path $dest | Select-Object Name
```

## Add Toolchain To User PATH (PowerShell)
```powershell
$toolBin = "$HOME\riscv-toolchain-14\bin"
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$toolBin*") {
  [Environment]::SetEnvironmentVariable("Path", "$currentUserPath;$toolBin", "User")
}
```

Close and reopen your terminal after updating PATH.

## Verify Toolchain
```powershell
riscv32-unknown-elf-as --version
riscv32-unknown-elf-ld --version
riscv32-unknown-elf-objcopy --version
```

## Build This Project
```powershell
.\build.bat
```

If your toolchain uses a different prefix, pass it explicitly:
```powershell
.\build.bat riscv-none-elf
```

## UART Terminal Setup (PuTTY)
- Speed: 115200
- Data bits: 8
- Stop bits: 1
- Parity: None
- Flow control: None

## UART Wiring (Pico 2 Target)
- GP0 = UART0 TX (target output)
- GP1 = UART0 RX (target input)
- GND must be common between target and USB-UART adapter/debug probe
- Cross wiring is required: adapter TX -> GP1, adapter RX -> GP0

<br>

# Hardware
## Raspberry Pi Pico 2 w/ Header [BUY](https://www.pishop.us/product/raspberry-pi-pico-2-with-header)
## USB A-Male to USB Micro-B Cable [BUY](https://www.pishop.us/product/usb-a-male-to-usb-micro-b-cable-6-inches)
## Raspberry Pi Pico Debug Probe [BUY](https://www.pishop.us/product/raspberry-pi-debug-probe)
## Complete Component Kit for Raspberry Pi [BUY](https://www.pishop.us/product/complete-component-kit-for-raspberry-pi)
## 10pc 25v 1000uF Capacitor [BUY](https://www.amazon.com/Cionyce-Capacitor-Electrolytic-CapacitorsMicrowave/dp/B0B63CCQ2N?th=1)
### 10% PiShop DISCOUNT CODE - KVPE_HS320548_10PC

<br>

# Build
```
.\build.bat
```

## Optional Toolchain Prefix Override
```
.\build.bat riscv-none-elf
```

<br>

# Clean
```
.\clean.bat
```

<br>

# Tutorial

A comprehensive 30-chapter technical book teaching RP2350 RISC-V assembly from absolute scratch.  Every line of assembler is explained.

## Foundations

### [Chapter 1: What Is a Computer?](TUTORIAL/CHAPTER-01.md)
- [The Fetch-Decode-Execute Cycle](TUTORIAL/CHAPTER-01.md#the-fetch-decode-execute-cycle)
- [The Three Core Components](TUTORIAL/CHAPTER-01.md#the-three-core-components)
- [Microcontroller vs Desktop Computer](TUTORIAL/CHAPTER-01.md#microcontroller-vs-desktop-computer)
- [What Is RP2350?](TUTORIAL/CHAPTER-01.md#what-is-rp2350)
- [What Is RISC-V?](TUTORIAL/CHAPTER-01.md#what-is-risc-v)
- [Why Assembly Language?](TUTORIAL/CHAPTER-01.md#why-assembly-language)
- [What We Are Building](TUTORIAL/CHAPTER-01.md#what-we-are-building)

### [Chapter 2: Number Systems — Binary, Hexadecimal, and Decimal](TUTORIAL/CHAPTER-02.md)
- [Decimal (Base 10)](TUTORIAL/CHAPTER-02.md#decimal-base-10)
- [Binary (Base 2)](TUTORIAL/CHAPTER-02.md#binary-base-2)
- [Hexadecimal (Base 16)](TUTORIAL/CHAPTER-02.md#hexadecimal-base-16)
- [Prefixes in Code](TUTORIAL/CHAPTER-02.md#prefixes-in-code)
- [Size Units in Computing](TUTORIAL/CHAPTER-02.md#size-units-in-computing)

### [Chapter 3: Memory — Addresses, Bytes, Words, and Endianness](TUTORIAL/CHAPTER-03.md)
- [The Byte-Addressable Model](TUTORIAL/CHAPTER-03.md#the-byte-addressable-model)
- [Words and Alignment](TUTORIAL/CHAPTER-03.md#words-and-alignment)
- [Endianness](TUTORIAL/CHAPTER-03.md#endianness)
- [Memory Regions on RP2350](TUTORIAL/CHAPTER-03.md#memory-regions-on-rp2350)
- [Memory-Mapped I/O](TUTORIAL/CHAPTER-03.md#memory-mapped-io)
- [Address Arithmetic](TUTORIAL/CHAPTER-03.md#address-arithmetic)

### [Chapter 4: What Is a Register?](TUTORIAL/CHAPTER-04.md)
- [Why Registers?](TUTORIAL/CHAPTER-04.md#why-registers)
- [The RISC-V Register File](TUTORIAL/CHAPTER-04.md#the-risc-v-register-file)
- [Register x0: The Hardwired Zero](TUTORIAL/CHAPTER-04.md#register-x0-the-hardwired-zero)
- [ABI Register Names](TUTORIAL/CHAPTER-04.md#abi-register-names)
- [Visualizing Registers](TUTORIAL/CHAPTER-04.md#visualizing-registers)

### [Chapter 5: Load-Store Architecture — How RISC-V Accesses Memory](TUTORIAL/CHAPTER-05.md)
- [The Load-Store Principle](TUTORIAL/CHAPTER-05.md#the-load-store-principle)
- [Why Load-Store?](TUTORIAL/CHAPTER-05.md#why-load-store)
- [RISC-V Load Instructions](TUTORIAL/CHAPTER-05.md#risc-v-load-instructions)
- [RISC-V Store Instructions](TUTORIAL/CHAPTER-05.md#risc-v-store-instructions)
- [Base + Offset Addressing](TUTORIAL/CHAPTER-05.md#base--offset-addressing)
- [The Memory Bus](TUTORIAL/CHAPTER-05.md#the-memory-bus)

### [Chapter 6: The Fetch-Decode-Execute Cycle in Detail](TUTORIAL/CHAPTER-06.md)
- [The Cycle Step by Step](TUTORIAL/CHAPTER-06.md#the-cycle-step-by-step)
- [Pipeline Concept](TUTORIAL/CHAPTER-06.md#pipeline-concept)
- [Tracing Through Our Firmware](TUTORIAL/CHAPTER-06.md#tracing-through-our-firmware)
- [The Program Counter is Everything](TUTORIAL/CHAPTER-06.md#the-program-counter-is-everything)

## RISC-V Instruction Set

### [Chapter 7: RISC-V ISA Overview](TUTORIAL/CHAPTER-07.md)
- [The RISC-V Design Philosophy](TUTORIAL/CHAPTER-07.md#the-risc-v-design-philosophy)
- [Our ISA String: rv32imac_zicsr](TUTORIAL/CHAPTER-07.md#our-isa-string-rv32imac_zicsr)
- [Instruction Encoding Summary](TUTORIAL/CHAPTER-07.md#instruction-encoding-summary)
- [How This Maps to Our Firmware](TUTORIAL/CHAPTER-07.md#how-this-maps-to-our-firmware)

### [Chapter 8: RISC-V Immediate and Upper-Immediate Instructions](TUTORIAL/CHAPTER-08.md)
- [What Is an Immediate?](TUTORIAL/CHAPTER-08.md#what-is-an-immediate)
- [I-Type Immediates (12-bit Signed)](TUTORIAL/CHAPTER-08.md#i-type-immediates-12-bit-signed)
- [Shift Immediates](TUTORIAL/CHAPTER-08.md#shift-immediates)
- [U-Type Instructions: LUI and AUIPC](TUTORIAL/CHAPTER-08.md#u-type-instructions-lui-and-auipc)
- [Building 32-bit Constants: LUI + ADDI](TUTORIAL/CHAPTER-08.md#building-32-bit-constants-lui--addi)
- [The LI Pseudoinstruction](TUTORIAL/CHAPTER-08.md#the-li-pseudoinstruction)
- [LA: Load Address](TUTORIAL/CHAPTER-08.md#la-load-address)

### [Chapter 9: RISC-V Arithmetic and Logic Instructions](TUTORIAL/CHAPTER-09.md)
- [R-Type Format Recap](TUTORIAL/CHAPTER-09.md#r-type-format-recap)
- [Addition and Subtraction](TUTORIAL/CHAPTER-09.md#addition-and-subtraction)
- [Logical Operations](TUTORIAL/CHAPTER-09.md#logical-operations)
- [Shift Operations](TUTORIAL/CHAPTER-09.md#shift-operations)
- [Comparison Instructions](TUTORIAL/CHAPTER-09.md#comparison-instructions)
- [MUL from M Extension](TUTORIAL/CHAPTER-09.md#mul-from-m-extension)
- [Read-Modify-Write Pattern](TUTORIAL/CHAPTER-09.md#read-modify-write-pattern)

### [Chapter 10: RISC-V Memory Access Instructions — Load and Store Deep Dive](TUTORIAL/CHAPTER-10.md)
- [Load Instruction Family](TUTORIAL/CHAPTER-10.md#load-instruction-family)
- [Store Instruction Family](TUTORIAL/CHAPTER-10.md#store-instruction-family)
- [Why Our Firmware Uses Only LW and SW](TUTORIAL/CHAPTER-10.md#why-our-firmware-uses-only-lw-and-sw)
- [Offset Encoding Constraints](TUTORIAL/CHAPTER-10.md#offset-encoding-constraints)
- [Complete Memory Access Map for Our Firmware](TUTORIAL/CHAPTER-10.md#complete-memory-access-map-for-our-firmware)

### [Chapter 11: RISC-V Branch Instructions](TUTORIAL/CHAPTER-11.md)
- [How Branches Work](TUTORIAL/CHAPTER-11.md#how-branches-work)
- [B-Type Encoding](TUTORIAL/CHAPTER-11.md#b-type-encoding)
- [The Six Branch Instructions](TUTORIAL/CHAPTER-11.md#the-six-branch-instructions)
- [Signed vs Unsigned Comparison](TUTORIAL/CHAPTER-11.md#signed-vs-unsigned-comparison)
- [Branches in Our Firmware](TUTORIAL/CHAPTER-11.md#branches-in-our-firmware)
- [Local Labels](TUTORIAL/CHAPTER-11.md#local-labels)
- [Branch Range Limitation](TUTORIAL/CHAPTER-11.md#branch-range-limitation)
- [No Flags Register](TUTORIAL/CHAPTER-11.md#no-flags-register)

### [Chapter 12: RISC-V Jumps, Calls, and Returns](TUTORIAL/CHAPTER-12.md)
- [JAL: Jump and Link](TUTORIAL/CHAPTER-12.md#jal-jump-and-link)
- [JALR: Jump and Link Register](TUTORIAL/CHAPTER-12.md#jalr-jump-and-link-register)
- [CALL Pseudoinstruction](TUTORIAL/CHAPTER-12.md#call-pseudoinstruction)
- [RET Pseudoinstruction](TUTORIAL/CHAPTER-12.md#ret-pseudoinstruction)
- [TAIL Pseudoinstruction](TUTORIAL/CHAPTER-12.md#tail-pseudoinstruction)
- [The Complete Call Chain in Our Firmware](TUTORIAL/CHAPTER-12.md#the-complete-call-chain-in-our-firmware)
- [Infinite Loops](TUTORIAL/CHAPTER-12.md#infinite-loops)
- [Nested Calls and the Stack](TUTORIAL/CHAPTER-12.md#nested-calls-and-the-stack)

## Assembly Programming

### [Chapter 13: Pseudoinstructions — What the Assembler Does For You](TUTORIAL/CHAPTER-13.md)
- [What Is a Pseudoinstruction?](TUTORIAL/CHAPTER-13.md#what-is-a-pseudoinstruction)
- [Complete Pseudoinstruction Reference](TUTORIAL/CHAPTER-13.md#complete-pseudoinstruction-reference)
- [Why Pseudoinstructions Matter](TUTORIAL/CHAPTER-13.md#why-pseudoinstructions-matter)
- [How to Tell if Something Is a Pseudoinstruction](TUTORIAL/CHAPTER-13.md#how-to-tell-if-something-is-a-pseudoinstruction)

### [Chapter 14: Assembler Directives — Controlling the Assembly Process](TUTORIAL/CHAPTER-14.md)
- [Sections](TUTORIAL/CHAPTER-14.md#sections)
- [Symbol Visibility](TUTORIAL/CHAPTER-14.md#symbol-visibility)
- [Alignment](TUTORIAL/CHAPTER-14.md#alignment)
- [Data Embedding](TUTORIAL/CHAPTER-14.md#data-embedding)
- [Constant Definitions](TUTORIAL/CHAPTER-14.md#constant-definitions)
- [File Inclusion](TUTORIAL/CHAPTER-14.md#file-inclusion)
- [Labels](TUTORIAL/CHAPTER-14.md#labels)
- [Putting It All Together](TUTORIAL/CHAPTER-14.md#putting-it-all-together)

### [Chapter 15: The Calling Convention and Stack Frames](TUTORIAL/CHAPTER-15.md)
- [The RISC-V ilp32 Calling Convention](TUTORIAL/CHAPTER-15.md#the-risc-v-ilp32-calling-convention)
- [The Stack](TUTORIAL/CHAPTER-15.md#the-stack)
- [Stack Frame Layout](TUTORIAL/CHAPTER-15.md#stack-frame-layout)
- [Function Types in Our Firmware](TUTORIAL/CHAPTER-15.md#function-types-in-our-firmware)
- [How Arguments Flow in Our Firmware](TUTORIAL/CHAPTER-15.md#how-arguments-flow-in-our-firmware)
- [Caller-Saved in Action](TUTORIAL/CHAPTER-15.md#caller-saved-in-action)

### [Chapter 16: Bitwise Operations for Hardware Programming](TUTORIAL/CHAPTER-16.md)
- [Bit Numbering](TUTORIAL/CHAPTER-16.md#bit-numbering)
- [The Four Fundamental Bit Operations](TUTORIAL/CHAPTER-16.md#the-four-fundamental-bit-operations)
- [The Read-Modify-Write Pattern](TUTORIAL/CHAPTER-16.md#the-read-modify-write-pattern)
- [Multi-Bit Fields](TUTORIAL/CHAPTER-16.md#multi-bit-fields)
- [Bit Testing: The BGEZ Trick](TUTORIAL/CHAPTER-16.md#bit-testing-the-bgez-trick)
- [Constants in Our Firmware](TUTORIAL/CHAPTER-16.md#constants-in-our-firmware)
- [Common Bit Patterns Summary](TUTORIAL/CHAPTER-16.md#common-bit-patterns-summary)

## Hardware Concepts

### [Chapter 17: Memory-Mapped I/O — Controlling Hardware Through Addresses](TUTORIAL/CHAPTER-17.md)
- [The Principle](TUTORIAL/CHAPTER-17.md#the-principle)
- [RP2350 Address Space Map](TUTORIAL/CHAPTER-17.md#rp2350-address-space-map)
- [Peripheral Register Structure](TUTORIAL/CHAPTER-17.md#peripheral-register-structure)
- [Register Types](TUTORIAL/CHAPTER-17.md#register-types)
- [Volatility](TUTORIAL/CHAPTER-17.md#volatility)
- [Why Order Matters](TUTORIAL/CHAPTER-17.md#why-order-matters)
- [The PPB (Private Peripheral Bus)](TUTORIAL/CHAPTER-17.md#the-ppb-private-peripheral-bus)
- [Atomic Access Concerns](TUTORIAL/CHAPTER-17.md#atomic-access-concerns)

### [Chapter 18: The RP2350 Microcontroller — Architecture and Hardware](TUTORIAL/CHAPTER-18.md)
- [RP2350 Block Diagram](TUTORIAL/CHAPTER-18.md#rp2350-block-diagram)
- [The Hazard3 RISC-V Core](TUTORIAL/CHAPTER-18.md#the-hazard3-risc-v-core)
- [Memory System](TUTORIAL/CHAPTER-18.md#memory-system)
- [Reset Infrastructure](TUTORIAL/CHAPTER-18.md#reset-infrastructure)
- [Clock Infrastructure](TUTORIAL/CHAPTER-18.md#clock-infrastructure)
- [GPIO System](TUTORIAL/CHAPTER-18.md#gpio-system)
- [UART Hardware](TUTORIAL/CHAPTER-18.md#uart-hardware)
- [Boot Sequence (High Level)](TUTORIAL/CHAPTER-18.md#boot-sequence-high-level)
- [What Our Firmware Must Do](TUTORIAL/CHAPTER-18.md#what-our-firmware-must-do)

## Build System

### [Chapter 19: The Linker Script — Placing Code in Memory](TUTORIAL/CHAPTER-19.md)
- [Why a Linker Script?](TUTORIAL/CHAPTER-19.md#why-a-linker-script)
- [Full Source: linker.ld](TUTORIAL/CHAPTER-19.md#full-source-linkerld)
- [Line-by-Line Walkthrough](TUTORIAL/CHAPTER-19.md#line-by-line-walkthrough)
- [Memory Layout After Linking](TUTORIAL/CHAPTER-19.md#memory-layout-after-linking)

### [Chapter 20: The Build Pipeline — From Assembly to UF2](TUTORIAL/CHAPTER-20.md)
- [The Four-Stage Pipeline](TUTORIAL/CHAPTER-20.md#the-four-stage-pipeline)
- [Toolchain Path Auto-Detection](TUTORIAL/CHAPTER-20.md#toolchain-path-auto-detection)
- [Object File Contents](TUTORIAL/CHAPTER-20.md#object-file-contents)
- [Examining the Final ELF](TUTORIAL/CHAPTER-20.md#examining-the-final-elf)

## Source Code Walkthroughs

### [Chapter 21: image_def.s — Boot Metadata Line by Line](TUTORIAL/CHAPTER-21.md)
- [Section and Alignment](TUTORIAL/CHAPTER-21.md#section-and-alignment)
- [Start Marker](TUTORIAL/CHAPTER-21.md#start-marker)
- [Image Type Item](TUTORIAL/CHAPTER-21.md#image-type-item)
- [Entry Point Item](TUTORIAL/CHAPTER-21.md#entry-point-item)
- [Last Item Marker](TUTORIAL/CHAPTER-21.md#last-item-marker)
- [Block Loop Pointer](TUTORIAL/CHAPTER-21.md#block-loop-pointer)
- [End Marker](TUTORIAL/CHAPTER-21.md#end-marker)
- [Complete Binary Dump](TUTORIAL/CHAPTER-21.md#complete-binary-dump)
- [Boot ROM Sequence](TUTORIAL/CHAPTER-21.md#boot-rom-sequence)

### [Chapter 22: constants.s — Every Definition Explained](TUTORIAL/CHAPTER-22.md)
- [Stack Constants](TUTORIAL/CHAPTER-22.md#stack-constants)
- [Crystal Oscillator Constants](TUTORIAL/CHAPTER-22.md#crystal-oscillator-constants)
- [System Constants](TUTORIAL/CHAPTER-22.md#system-constants)
- [Clock Constants](TUTORIAL/CHAPTER-22.md#clock-constants)
- [Reset Controller Constants](TUTORIAL/CHAPTER-22.md#reset-controller-constants)
- [GPIO Constants](TUTORIAL/CHAPTER-22.md#gpio-constants)
- [UART Constants](TUTORIAL/CHAPTER-22.md#uart-constants)
- [How Constants Are Used](TUTORIAL/CHAPTER-22.md#how-constants-are-used)

### [Chapter 23: stack.s and vector_table.s — Line by Line](TUTORIAL/CHAPTER-23.md)
- [Part 1: stack.s](TUTORIAL/CHAPTER-23.md#part-1-stacks)
- [Part 2: vector_table.s](TUTORIAL/CHAPTER-23.md#part-2-vector_tables)
- [Why Both Files Exist](TUTORIAL/CHAPTER-23.md#why-both-files-exist)

### [Chapter 24: reset_handler.s — The Boot Sequence Line by Line](TUTORIAL/CHAPTER-24.md)
- [The Reset_Handler Function](TUTORIAL/CHAPTER-24.md#the-reset_handler-function)
- [Default_Trap_Handler](TUTORIAL/CHAPTER-24.md#default_trap_handler)
- [Init_Trap_Vector](TUTORIAL/CHAPTER-24.md#init_trap_vector)
- [The Complete Initialization Order](TUTORIAL/CHAPTER-24.md#the-complete-initialization-order)

### [Chapter 25: xosc.s — Crystal Oscillator Initialization Line by Line](TUTORIAL/CHAPTER-25.md)
- [Function 1: Init_XOSC](TUTORIAL/CHAPTER-25.md#function-1-init_xosc)
- [Function 2: Enable_XOSC_Peri_Clock](TUTORIAL/CHAPTER-25.md#function-2-enable_xosc_peri_clock)
- [Register Usage Summary](TUTORIAL/CHAPTER-25.md#register-usage-summary)
- [Read-Modify-Write Pattern](TUTORIAL/CHAPTER-25.md#read-modify-write-pattern)

### [Chapter 26: reset.s — Releasing IO_BANK0 from Reset](TUTORIAL/CHAPTER-26.md)
- [Background: The Reset Controller](TUTORIAL/CHAPTER-26.md#background-the-reset-controller)
- [Line-by-Line Walkthrough](TUTORIAL/CHAPTER-26.md#line-by-line-walkthrough)
- [The Bit-Clear Pattern in Detail](TUTORIAL/CHAPTER-26.md#the-bit-clear-pattern-in-detail)
- [The Polling Pattern](TUTORIAL/CHAPTER-26.md#the-polling-pattern)

### [Chapter 27: uart.s Part 1 — Release Reset and Initialization](TUTORIAL/CHAPTER-27.md)
- [Function 1: UART_Release_Reset](TUTORIAL/CHAPTER-27.md#function-1-uart_release_reset)
- [Function 2: UART_Init](TUTORIAL/CHAPTER-27.md#function-2-uart_init)
- [Register Map Summary](TUTORIAL/CHAPTER-27.md#register-map-summary)

### [Chapter 28: uart.s Part 2 — Transmit and Receive](TUTORIAL/CHAPTER-28.md)
- [Function 1: UART0_Out — Blocking Transmit](TUTORIAL/CHAPTER-28.md#function-1-uart0_out--blocking-transmit)
- [Function 2: UART0_In — Blocking Receive](TUTORIAL/CHAPTER-28.md#function-2-uart0_in--blocking-receive)
- [The Echo Loop](TUTORIAL/CHAPTER-28.md#the-echo-loop)
- [The UARTDR Register: Dual-Purpose](TUTORIAL/CHAPTER-28.md#the-uartdr-register-dual-purpose)
- [Potential Issues](TUTORIAL/CHAPTER-28.md#potential-issues)

### [Chapter 29: main.s — The Application Entry Point](TUTORIAL/CHAPTER-29.md)
- [The .text Section](TUTORIAL/CHAPTER-29.md#the-text-section)
- [The Echo Loop](TUTORIAL/CHAPTER-29.md#the-echo-loop)
- [The Data Sections](TUTORIAL/CHAPTER-29.md#the-data-sections)
- [Register Usage Throughout the Loop](TUTORIAL/CHAPTER-29.md#register-usage-throughout-the-loop)
- [Why This Code Is Minimal](TUTORIAL/CHAPTER-29.md#why-this-code-is-minimal)
- [Complete Execution Timeline](TUTORIAL/CHAPTER-29.md#complete-execution-timeline)

## Integration

### [Chapter 30: Full Integration — Build, Flash, Wire, and Test](TUTORIAL/CHAPTER-30.md)
- [Part 1: The Project Structure](TUTORIAL/CHAPTER-30.md#part-1-the-project-structure)
- [Part 2: The Build Pipeline](TUTORIAL/CHAPTER-30.md#part-2-the-build-pipeline)
- [Part 3: The Memory Map After Build](TUTORIAL/CHAPTER-30.md#part-3-the-memory-map-after-build)
- [Part 4: Hardware Setup](TUTORIAL/CHAPTER-30.md#part-4-hardware-setup)
- [Part 5: Flashing the Firmware](TUTORIAL/CHAPTER-30.md#part-5-flashing-the-firmware)
- [Part 6: Testing with a Terminal](TUTORIAL/CHAPTER-30.md#part-6-testing-with-a-terminal)
- [Part 7: The Complete Boot Flow](TUTORIAL/CHAPTER-30.md#part-7-the-complete-boot-flow)
- [Part 8: Debugging Tips](TUTORIAL/CHAPTER-30.md#part-8-debugging-tips)
- [Part 9: What You Have Learned](TUTORIAL/CHAPTER-30.md#part-9-what-you-have-learned)
- [Part 10: Where to Go Next](TUTORIAL/CHAPTER-30.md#part-10-where-to-go-next)

<br>

# main.s Code
```
/**
 * FILE: main.s
 *
 * DESCRIPTION:
 * RP2350 Bare-Metal UART Main Application (RISC-V).
 * 
 * BRIEF:
 * Main application entry point for RP2350 RISC-V UART driver. Contains the
 * main loop that echoes UART input to output.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 2, 2025
 * UPDATE DATE: November 27, 2025
 */


.include "constants.s"

/**
 * Initialize the .text section. 
 * The .text section contains executable code.
 */
.section .text                                   # code section
.align 2                                         # align to 4-byte boundary

/**
 * @brief   Main application entry point.
 *
 * @details Implements the infinite blink loop.
 *
 * @param   None
 * @retval  None
 */
.global main                                     # export main
.type main, @function                            # mark as function
main:
.Loop:
  call  UART0_In                                 # call UART0_In
  call  UART0_Out                                # call UART0_Out
  j     .Loop                                    # loop forever
  ret                                            # return to caller

/**
 * Test data and constants.
 * The .rodata section is used for constants and static data.
 */
.section .rodata                                 # read-only data section

/**
 * Initialized global data.
 * The .data section is used for initialized global or static variables.
 */
.section .data                                   # data section

/**
 * Uninitialized global data.
 * The .bss section is used for uninitialized global or static variables.
 */
.section .bss                                    # BSS section
```

<br>

# License
[Apache License 2.0](https://github.com/mytechnotalent/RP2350_UART_Driver/blob/main/LICENSE)
