/*
 * FreeRTOS Kernel V10.3.1
 * Copyright (C) 2020 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * https://www.FreeRTOS.org
 * https://github.com/FreeRTOS
 *
 * 1 tab == 4 spaces!
 */

#include <arch/csfrs.h>


/* Protections disabled */
#define portINITIAL_CORECON     ( 0x00000000UL )
/* OS Interrupt and Trap mechanisms */
#define portRESTORE_PSW_MASK    ( ~( 0x000000FFUL ) )

.section ".text", "ax"

.extern irq_vector
.extern freeertos_vector_table
.extern pxCurrentTCB
.extern ulPortSwitchRequired

.global vPortStartFirstTask
.global vYieldHandler
.global vUnsupportedTrap
.global vInterruptHandler

.macro LOAD_ADDR ra, label
    movh.a \ra, hi:\label
    lea    \ra, [\ra]lo:\label
.endm

.macro LOAD_DATA rd, label
    movh   \rd, hi:\label
    addi   \rd, \rd, lo:\label
.endm


/*-----------------------------------------------------------------------------*/
.macro portSAVE_CONTEXT

    mfcr    %d2, $PCXI

    /* pxCurrentTCB-> pxTopOfStack is already in CSA format */
    LOAD_ADDR   %a2, pxCurrentTCB
    ld.a    %a2, [%a2]
    ld.a    %a2, [%a2]
    st.w    [%a2], %d2
    dsync

.endm


/*-----------------------------------------------------------------------------*/
.macro portRESTORE_CONTEXT

    /* pxCurrentTCB-> pxTopOfStack is already in CSA format */
    LOAD_ADDR   %a2, pxCurrentTCB
    ld.a    %a2, [%a2]
    ld.a    %a2, [%a2]
    ld.w    %d2, [%a2]
    dsync

    mtcr    $PCXI, %d2
    isync

.endm


/*-----------------------------------------------------------------------------*/
vPortStartFirstTask:

    /* Configure CORECON */
    mov     %d2, portINITIAL_CORECON
    mtcr    CSFR_CORECON, %d2

    /* Configure vector tables */
    LOAD_DATA   %d2, freertos_irq_table
    mtcr    $BIV, %d2

    LOAD_DATA   %d2, freertos_trap_table
    mtcr    $BTV, %d2
    isync

    /* Clear the PSW.CDC to enable the use of an RFE 
        without it generating an exception  */
    mfcr    %d2, $PSW
    LOAD_DATA   %d3, portRESTORE_PSW_MASK
    and     %d2, %d3
    mtcr    $PSW, %d2
    isync

    portRESTORE_CONTEXT
    rslcx

    rfe


/*-----------------------------------------------------------*/
vYieldHandler:

    /* Only syscall 0 is currently supported */
    jne %d15, 0, vUnsupportedTrap

    svlcx
    portSAVE_CONTEXT

    call    vTaskSwitchContext

    portRESTORE_CONTEXT
    rslcx

    rfe


/*-----------------------------------------------------------*/
vUnsupportedTrap:

    debug
    j .


/*---------------------------------------------------------------------------*/
vInterruptHandler:

    svlcx
    enable
    /* Interrupts are re-enabled at this point */

    call ir_handle

    /* Check if IRQ requested task switch */
    LOAD_ADDR   %a2, ulPortSwitchRequired
    ld.w    %d2, [%a2]
    jz      %d2, no_ctx_switch

    /* Task switch requested */
    disable

    mov     %d2, 0
    st.w    [%a2], %d2

    portSAVE_CONTEXT

    call    vTaskSwitchContext

    portRESTORE_CONTEXT

no_ctx_switch:

    rslcx

    rfe