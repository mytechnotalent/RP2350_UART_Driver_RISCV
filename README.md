<img src="https://github.com/mytechnotalent/RP2350_UART_Driver/blob/main/RP2350_UART_Driver_RISCV.png?raw=true">

## FREE Reverse Engineering Self-Study Course [HERE](https://github.com/mytechnotalent/Reverse-Engineering-Tutorial)
### VIDEO PROMO [HERE](https://www.youtube.com/watch?v=aD7X9sXirF8)

<br>

# RP2350 UART Driver RISC-V
An RP2350 RISC-V UART driver written entirely in Assembler.

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
$dest = "C:\Users\assem.KEVINTHOMAS\OneDrive\Documents\riscv-toolchain-14"

Invoke-WebRequest -Uri $url -OutFile $zipPath
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
Get-ChildItem -Path $dest | Select-Object Name
```

## Add Toolchain To User PATH (PowerShell)
```powershell
$toolBin = "C:\Users\assem.KEVINTHOMAS\OneDrive\Documents\riscv-toolchain-14\bin"
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
