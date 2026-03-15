/**
 * FILE: gpio.s
 *
 * DESCRIPTION:
 * RP2350 GPIO Functions (RISC-V).
 * 
 * BRIEF:
 * Provides GPIO configuration, set, and clear function placeholders.
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
 * @brief   Configure GPIO.
 *
 * @details Configures a GPIO pin's pad control and function select.
 *
 * @param   r0 - PAD_OFFSET
 * @param   r1 - CTRL_OFFSET
 * @param   r2 - GPIO
 * @retval  None
 */
.global GPIO_Config
.type GPIO_Config, @function
GPIO_Config:
  ret                                            # placeholder for future SIO GPIO support

/**
 * @brief   GPIO set.
 *
 * @details Drives GPIO output high via coprocessor.
 *
 * @param   r0 - GPIO
 * @retval  None
 */
.global GPIO_Set
.type GPIO_Set, @function
GPIO_Set:
  ret                                            # placeholder for future SIO GPIO support

/**
 * @brief   GPIO clear.
 *
 * @details Drives GPIO output high via coprocessor.
 *
 * @param   r0 - GPIO
 * @retval  None
 */
.global GPIO_Clear
.type GPIO_Clear, @function
GPIO_Clear:
  ret                                            # placeholder for future SIO GPIO support
