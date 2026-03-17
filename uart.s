/**
 * FILE: uart.s
 *
 * DESCRIPTION:
 * RP2350 UART Functions (RISC-V).
 * 
 * BRIEF:
 * Provides UART initialization, transmit, and receive functions for
 * UART0 on the RP2350.
 *
 * AUTHOR: Kevin Thomas
 * CREATION DATE: November 27, 2025
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
 * @brief   Release UART0 from reset and wait until it is ready.
 *
 * @details Clears the UART0 reset bit in the Reset controller (RESETS->RESET)
 *          and polls the corresponding bit in RESETS->RESET_DONE until the
 *          UART0 block is no longer in reset. This ensures UART registers are
 *          accessible before configuring the peripheral.
 *
 * @param   None
 * @retval  None
 */
.global UART_Release_Reset
.type UART_Release_Reset, @function
UART_Release_Reset:
  li    t0, RESETS_RESET                         # load RESETS->RESET address
  lw    t1, 0(t0)                                # read RESETS->RESET value
  li    t2, (1<<26)                              # UART0 reset bit mask
  not   t2, t2                                   # invert mask
  and   t1, t1, t2                               # clear UART0 reset bit
  sw    t1, 0(t0)                                # write value back to RESETS->RESET
.UART_Release_Reset_Wait:
  li    t0, RESETS_RESET_DONE                    # load RESETS->RESET_DONE address
  lw    t1, 0(t0)                                # read RESETS->RESET_DONE value
  li    t2, (1<<26)                              # UART0 done mask
  and   t1, t1, t2                               # test UART0 reset-done bit
  beqz  t1, .UART_Release_Reset_Wait             # loop until UART0 is out of reset
  ret                                            # return

/**
 * @brief   Initialize UART0 (pins, baud divisors, line control and enable).
 *
 * @details Configures IO_BANK0 pins 0 (TX) and 1 (RX) to the UART function
 *          and programs the corresponding pad controls in PADS_BANK0. It
 *          programs the integer and fractional baud divisors (UARTIBRD and
 *          UARTFBRD), configures UARTLCR_H for 8-bit transfers and FIFOs,
 *          and enables the UART (UARTCR: UARTEN + TXE + RXE).
 *          The routine assumes the UART0 base is available at the
 *          `UART0_BASE` symbol. The selected divisors (IBRD=6, FBRD=33) are
 *          chosen to match the expected peripheral clock; if your UART
 *          peripheral clock differs, adjust these values accordingly.
 *
 * @param   None
 * @retval  None
 */
.global UART_Init
.type UART_Init, @function
UART_Init:
  li    t0, IO_BANK0_BASE                        # load IO_BANK0 base
  li    t1, 2                                    # FUNCSEL = 2 -> select UART function
  sw    t1, 0x04(t0)                             # write FUNCSEL to GPIO0_CTRL (pin0 -> TX)
  sw    t1, 0x0c(t0)                             # write FUNCSEL to GPIO1_CTRL (pin1 -> RX)
  li    t0, PADS_BANK0_BASE                      # load PADS_BANK0 base
  li    t1, 0x04                                 # pad config value for TX
  sw    t1, 0x04(t0)                             # write PAD0 config (TX pad)
  li    t1, 0x40                                 # pad config value for RX
  sw    t1, 0x08(t0)                             # write PAD1 config (RX pad)
  li    t0, UART0_BASE                           # load UART0 base address
  li    t1, 0                                    # prepare 0 to disable UARTCR
  sw    t1, 0x30(t0)                             # UARTCR = 0 (disable UART while configuring)
  li    t1, 6                                    # integer baud divisor (IBRD = 6)
  sw    t1, 0x24(t0)                             # UARTIBRD = 6
  li    t1, 33                                   # fractional baud divisor (FBRD = 33)
  sw    t1, 0x28(t0)                             # UARTFBRD = 33
  li    t1, 112                                  # UARTLCR_H = 0x70 (FIFO enable + 8-bit)
  sw    t1, 0x2c(t0)                             # UARTLCR_H = 0x70
  li    t1, ((3<<8) | 1)                         # UARTEN + TXE + RXE
  sw    t1, 0x30(t0)                             # UARTCR = enable
  ret                                            # return

/**
 * @brief   UART0 transmit (blocking).
 *
 * @details Waits for TX FIFO to be not full, then writes the lowest 8 bits of r0 to UART0.
 *          Data to send must be in r0 on entry.
 *
 * @param   r0: byte to transmit (lower 8 bits used)
 * @retval  None
 */
.global UART0_Out
.type UART0_Out, @function
UART0_Out:
.UART0_Out_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
  lw    t1, 0x18(t0)                             # read UARTFR
  andi  t1, t1, 32                               # mask TXFF bit
  bnez  t1, .UART0_Out_loop                      # if TX FIFO is full, loop
  andi  a0, a0, 0xff                             # keep lower 8 bits only
  sw    a0, 0x00(t0)                             # write data to UARTDR
  ret                                            # return

/**
 * @brief   UART0 receive (blocking).
 *
 * @details Waits for RX FIFO to be not empty, then reads a byte from UART0 into r0.
 *
 * @param   None
 * @retval  r0: received byte (lower 8 bits valid)
 */
.global UART0_In
.type UART0_In, @function
UART0_In:
.UART0_In_loop:
  li    t0, UART0_BASE                           # base address for uart0 registers
  lw    t1, 0x18(t0)                             # read UARTFR
  andi  t1, t1, 16                               # mask RXFE bit
  bnez  t1, .UART0_In_loop                       # if RX FIFO is empty, loop
  lw    a0, 0x00(t0)                             # load data from UARTDR into a0
  andi  a0, a0, 0xff                             # keep lower 8 bits valid
  ret                                            # return
