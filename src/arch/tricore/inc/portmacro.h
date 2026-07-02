/*
 * FreeRTOS Kernel <DEVELOPMENT BRANCH>
 * Copyright (C) 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * SPDX-License-Identifier: MIT
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
 */

#ifndef PORTMACRO_H
#define PORTMACRO_H

#ifdef __cplusplus
    extern "C" {
#endif

#include <stdint.h>

/* TriCore specific includes. */
#include "port_tricore.h"


/*-----------------------------------------------------------
 * Port specific definitions.
 *
 * The settings in this file configure FreeRTOS correctly for the
 * given hardware and compiler.
 *
 * These settings should not be altered.
 *-----------------------------------------------------------
 */

/* TYPE DEFINITIONS */
/*---------------------------------------------------------------------------*/
#define portCHAR        char
#define portFLOAT       float
#define portDOUBLE      double
#define portLONG        long
#define portSHORT       short
#define portSTACK_TYPE  unsigned long
#define portBASE_TYPE   long

typedef portSTACK_TYPE StackType_t;
typedef long BaseType_t;
typedef unsigned long UBaseType_t;

#if( configUSE_16_BIT_TICKS == 1 )
    typedef unsigned TickType_t;
    #define portMAX_DELAY ( TickType_t ) 0xffff
#else
    typedef unsigned TickType_t;
    #define portMAX_DELAY ( TickType_t ) 0xffffffffUL
    
    /* 32-bit tick type on a 32-bit architecture, so reads of the tick count do
    not need to be guarded with a critical section. */
    #define portTICK_TYPE_IS_ATOMIC 1
    
#endif


// ARCHITECTURE SPECIFICS
/*---------------------------------------------------------------------------*/
#define portSTACK_GROWTH                        ( -1 )
#define portTICK_PERIOD_MS                      ( ( TickType_t ) 2000 / configTICK_RATE_HZ )
#define portBYTE_ALIGNMENT                      4
#define portASSERT_IF_IN_ISR()                  vPortAssertIfInISR()
#define portNOP()                               TriCore__nop()
#define portCRITICAL_NESTING_IN_TCB             1
#define portRESTORE_FIRST_TASK_PRIORITY_LEVEL   1

typedef struct MPU_SETTINGS { uint32_t  ulNotUsed; } xMPU_SETTINGS;

/* Define away the instruction from the Restore Context Macro. */
#define portPRIVILEGE_BIT   0x0UL

/* CSA Manipulation */
#define portCSA_TO_ADDRESS( pCSA ) ( ( uint32_t * ) (       \
        ( ( pCSA & 0x000F0000 ) << 12 ) |                   \
        ( ( pCSA & 0x0000FFFF ) << 6 ) ) )
#define portADDRESS_TO_CSA( pAddress )  ( ( uint32_t ) (    \
        ( ( ( uint32_t )pAddress & 0xF0000000 ) >> 12 ) |   \
        ( ( ( uint32_t )pAddress & 0x003FFFC0 ) >> 6 ) ) )

/* As this port holds a CSA address in pxTopOfStack, the assert that checks the
pxTopOfStack alignment is removed. */
#define portALIGNMENT_ASSERT_pxCurrentTCB ( void )

#define portYIELD() TriCore__syscall( 0 )
#define portYIELD_FROM_ISR( xSwitchRequired )       \
{                                                   \
    extern volatile uint32_t ulPortSwitchRequired;  \
                                                    \
    do {                                            \
        if( xSwitchRequired != pdFALSE )            \
        {                                           \
            ulPortSwitchRequired = pdTRUE;          \
        }                                           \
    } while( 0 )                                    \
}

/*
 * Port specific clean up macro required to free the CSAs that were consumed by
 * a task that has since been deleted.
 */
void vPortReclaimCSA( uint32_t *pulTCB );
#define portCLEAN_UP_TCB( pulTCB )   vPortReclaimCSA( ( uint32_t * ) ( pulTCB ) )

#define portMEMORY_BARRIER() TriCore__mem_barrier()

__attribute__( ( always_inline ) ) static inline void vPortAssertIfInISR( void )
{
    configASSERT( ( TriCore__mfcr( TRICORE_CPU_PSW ) & ( 1U << 9U ) ) == 0x00000000U);
}

extern __attribute__( (__noreturn__) ) void vPortLoopForever( void );


// CRITICAL SECTION MANAGEMENT
/*---------------------------------------------------------------------------*/

#define portCCPN_MASK   ( 0x000000FFUL )

extern void vTaskEnterCritical( void );
extern void vTaskExitCritical( void );

#define portENTER_CRITICAL()    vTaskEnterCritical()
#define portEXIT_CRITICAL()     vTaskExitCritical()

__attribute__( ( always_inline ) ) static inline uint32_t ulPortSetCCPN( uint32_t ulCCPN )
{
    uint32_t ulICR;
    uint32_t ulPrevCCPN;

    TriCore__disable();

    ulICR = TriCore__mfcr(TRICORE_CPU_ICR);
    ulPrevCCPN = ulICR & portCCPN_MASK;

    ulICR &= ~portCCPN_MASK;
    ulICR |= ulCCPN;
    TriCore__mtcr(TRICORE_CPU_ICR, ulICR);
    TriCore__isync();

    TriCore__enable();

    return ulPrevCCPN;
}

/* Set ICR.CCPN to configMAX_SYSCALL_INTERRUPT_PRIORITY */
#define portDISABLE_INTERRUPTS()    ((void)ulPortSetCCPN(configMAX_SYSCALL_INTERRUPT_PRIORITY))
/* Clear ICR.CCPN to allow all interrupt priorities */
#define portENABLE_INTERRUPTS()     ((void)ulPortSetCCPN(0))
/* Set ICR.CCPN to configMAX_SYSCALL_INTERRUPT_PRIORITY */
#define portSET_INTERRUPT_MASK_FROM_ISR() ulPortSetCCPN(configMAX_SYSCALL_INTERRUPT_PRIORITY)
/* Set ICR.CCPN to mask */
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(mask) ((void)ulPortSetCCPN(mask))


// TASK FUNCTION MACROS
/*---------------------------------------------------------------------------*/

// Task functions macros as described in FreeRTOS.org
#define portTASK_FUNCTION_PROTO(vFunction, pvParameters) \
    void vFunction(void *pvParameters)

#define portTASK_FUNCTION(vFunction, pvParameters) \
    void vFunction(void *pvParameters)

#ifdef __cplusplus
    }
#endif

#endif /* PORTMACRO_H */