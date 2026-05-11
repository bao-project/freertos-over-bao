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

#include "FreeRTOSConfig.h"

#define TRAP0_CAUSE  0x40

.section ".text", "ax"

.extern _vTaskSwitchContext
.extern _pxCurrentTCB
.extern _xPortSwitchRequired
.extern _xInterruptNesting
.extern _pxIRQStackTop
.extern _irq_handle
.extern _freertos_vector_table

.global _vPortStartFirstTask
.global _vExceptionHandler
.global _vInterruptHandler


.macro LOAD_ADDR    sym, reg
    movhi hi(\sym), r0, \reg
    movea lo(\sym), \reg, \reg
.endm

.macro LOAD_FROM_SR regID, selID, rd
    stsr \regID, \rd, \selID
.endm

.macro STORE_TO_SR  regID, selID, rd
    ldsr \rd, \regID, \selID
.endm


/*-----------------------------------------------------------------------------*/
.macro portSAVE_CONTEXT
    prepare {lp}, 0

    pushsp r6 - r19                     // Save caller-saved GPRs
    pushsp r1 - r2

    LOAD_FROM_SR 1, 0, r6               // Save EIPSW
    LOAD_FROM_SR 0, 0, r7               // Save EIPC
#if ( configENABLE_FPU == 1 )
    LOAD_FROM_SR 6, 0, r8               // FPU used
    pushsp r6 - r8                      // Save FPSR
#else
    pushsp r6 - r7                      // FPU not used
#endif

    pushsp r20 - r30                    // Save callee-saved GPRs

    LOAD_ADDR _pxCurrentTCB, r8         // pxCurrentTCB->pxTopOfStack = SP
    ld.w 0[r8], r9
    st.w sp, 0[r9]
.endm


/*-----------------------------------------------------------------------------*/
.macro portRESTORE_CONTEXT
    LOAD_ADDR _pxCurrentTCB, r8         // SP = pxCurrentTCB->pxTopOfStack
    ld.w 0[r8], r9
    ld.w 0[r9], sp

    popsp r20 - r30                     // Restore callee-saved GPRs

#if ( configENABLE_FPU == 1 )
    popsp r6 - r8                       // FPU used
    STORE_TO_SR 6, 0, r8                // Restore FPSR
#else
    popsp r6 - r7                       // FPU not used
#endif
    STORE_TO_SR 0, 0, r7                // Restore EIPC
    STORE_TO_SR 1, 0, r6                // Restore EIPSW

    popsp r1 - r2                       // Restore caller-saved GPRs
    popsp r6 - r19

    dispose 0, {lp}
.endm


/*-----------------------------------------------------------------------------*/
_vPortStartFirstTask:

    // Overwrite vector table address
    LOAD_ADDR _freertos_vector_table, r6
    ori 0x2, r6, r6                         // set EBASE.DV
    STORE_TO_SR 3, 1, r6

    portRESTORE_CONTEXT

    eiret


/*-----------------------------------------------------------*/
_vExceptionHandler:

    portSAVE_CONTEXT

    LOAD_FROM_SR 13, 0, r6
    mov TRAP0_CAUSE, r7
    cmp r6, r7
    bne _unsupported_exception

    jarl _vTaskSwitchContext, lp

    portRESTORE_CONTEXT

    eiret

_unsupported_exception:
    br _unsupported_exception

/*---------------------------------------------------------------------------*/
_vInterruptHandler:

    prepare {lp}, 0

    pushsp r6 - r19                     // Save caller-saved GPRs
    pushsp r1 - r2

    LOAD_FROM_SR 1, 0, r6               // Save EIPSW
    LOAD_FROM_SR 0, 0, r7               // Save EIPC
#if ( configENABLE_FPU == 1 )
    LOAD_FROM_SR 6, 0, r8               // FPU used
    pushsp r6 - r8                      // Save FPSR
#else
    pushsp r6 - r7                      // FPU not used
#endif

    // Check whether there are preempted IRQs
    LOAD_ADDR _xInterruptNesting, r6
    ld.w 0[r6], r7
    cmp 0, r7                           // if ( xInterruptNesting == 0 )
    bne no_switch_sp                    // {

    // Switch to IRQ SP if there are no preempted IRQs (we come from normal execution)
    LOAD_ADDR _pxCurrentTCB, r8         //     pxCurrentTCB->pxTopOfStack = SP
    ld.w 0[r8], r9
    st.w sp, 0[r9]

    LOAD_ADDR _pxIRQStackTop, r8        //     SP = IRQ stack
    ld.w 0[r8], r9
    mov r9, sp

no_switch_sp:                           // }
    add 1, r7                           // xInterruptNesting++
    st.w r7, 0[r6]

    LOAD_FROM_SR 13, 0, r6              // Save EI level Interrupt Cause
    mov 0x7FF, r7
	and r7, r6                          // Mask EIINT source

    ei                                  // Enable interrupt (enable interrupt nesting)
    jarl _irq_handle, lp                // Call corresponding handler
    di                                  // Disable interrupt (disable interrupt nesting)

    LOAD_ADDR _xInterruptNesting, r6    // xInterruptNesting--
    ld.w 0[r6], r7
    add -1, r7
    st.w r7, 0[r6]

    cmp 0, r7                           // if ( xInterruptNesting == 0 )
    bne no_switch_ctx                   // {

    // Restore non-IRQ SP
    LOAD_ADDR _pxCurrentTCB, r8         //     SP = pxCurrentTCB->pxTopOfStack
    ld.w 0[r8], r9
    ld.w 0[r9], sp

    // Check if IRQ requested task switch
    LOAD_ADDR _xPortSwitchRequired, r6
    ld.w 0[r6], r7
    cmp 0, r7                           //     if ( xPortSwitchRequired )
    be no_switch_ctx                    //     {

    // Task switch requested: save remaining ctx
    st.w r0, 0[r6]                      //         xPortSwitchRequired = pdFALSE
    pushsp r20 - r30                    //         Save callee-saved GPRs
    st.w sp, 0[r9]                      //         pxCurrentTCB->pxTopOfStack = SP

    jarl _vTaskSwitchContext, lp        //         vTaskSwitchContext()

    LOAD_ADDR _pxCurrentTCB, r8         //         SP = pxCurrentTCB->pxTopOfStack
    ld.w 0[r8], r9
    ld.w 0[r9], sp

    popsp r20 - r30                     //         Restore callee-saved GPRs
                                        //     }
                                        // }
no_switch_ctx:
#if ( configENABLE_FPU == 1 )
    popsp r6 - r8                       // FPU used
    STORE_TO_SR 6, 0, r8                // Restore FPSR
#else
    popsp r6 - r7                       // FPU not used
#endif
    STORE_TO_SR 0, 0, r7                // Restore EIPC
    STORE_TO_SR 1, 0, r6                // Restore EIPSW

    popsp r1 - r2                       // Restore caller-saved GPRs
    popsp r6 - r19

    dispose 0, {lp}

    eiret
