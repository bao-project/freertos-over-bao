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
 * http://www.FreeRTOS.org
 * http://aws.amazon.com/freertos
 *
 * 1 tab == 4 spaces!
 */

#include "FreeRTOS.h"
#include "task.h"
#include "portmacro.h"
#include <irq.h>
#include <plat.h>
#include <srs.h>
#include <timer.h>
#include <string.h>


// CUSTOM FUNCTION HEADERS & VARIABLES
/*---------------------------------------------------------------------------*/

/* Assumes increment won't go over 32-bits. */
const uint64_t uxTimerIncrementsForOneTick = ( uint64_t ) ( ( configCPU_CLOCK_HZ ) / ( configTICK_RATE_HZ ) );

/* Counts the interrupt nesting depth. A context switch is only performed 
    if the nesting depth is 0 */
volatile BaseType_t xInterruptNesting = 0;

/* Set to 1 to pend a context switch from an ISR. */
volatile BaseType_t xPortSwitchRequired = pdFALSE;

/*
 * Setup the timer to generate the tick interrupt at the required frequency.
 */
void vPortSetupTimerInterrupt( void );

/*
 * The tick interrupt handler.
 */
void xPortSysTickHandler( unsigned int dummy );

/*
 * Start first task is a separate function so it can be tested in isolation.
 */
extern void vPortStartFirstTask( void );

/*
 * Used to catch tasks that attempt to return from their implementing function.
 */
static void prvTaskExitError( void );

/*---------------------------------------------------------------------------*/


// CONFIGURATION OVERRIDE
/*---------------------------------------------------------------------------*/

/* Let the user override the pre-loading of the initial LR with the address of
    prvTaskExitError() in case it messes up unwinding of the stack in the debugger. */
#ifdef configTASK_RETURN_ADDRESS
	#define portTASK_RETURN_ADDRESS	configTASK_RETURN_ADDRESS
#else
	#define portTASK_RETURN_ADDRESS	prvTaskExitError
#endif /* configTASK_RETURN_ADDRESS */

/* Let the user define configSETUP_TICK_INTERRUPT() in ´FreeRTOSConfig.h´ 
    to override tick interrupt configuration */
#ifdef configSETUP_TICK_INTERRUPT
    #define portSETUP_TICK_INTERRUPT()  configSETUP_TICK_INTERRUPT()
#else
    #define portSETUP_TICK_INTERRUPT()  vPortSetupTimerInterrupt()
#endif /* configSETUP_TICK_INTERRUPT */

/* If portPRELOAD_REGISTERS is 1 then registers will be given an initial value
    when a task is created. This helps in debugging at the cost of code size. */
#define portPRELOAD_REGISTERS       ( 0 )

/*---------------------------------------------------------------------------*/


// IRQ STACK 
/*---------------------------------------------------------------------------*/

#ifndef configIRQ_STACK_SIZE
    #define configIRQ_STACK_SIZE    ( 512 )
#endif

static StackType_t xIRQStack[ (configMINIMAL_STACK_SIZE * 4) ] __attribute__((aligned(16)));
StackType_t* const pxIRQStackTop = &xIRQStack[ (configMINIMAL_STACK_SIZE * 4) ];


// STANDARD FREERTOS FUNCTIONS
/*---------------------------------------------------------------------------*/

/*
 * Setup the hardware ready for the scheduler to take control. This generally
 * sets up a tick interrupt and sets timers for the correct tick frequency.
 */
BaseType_t xPortStartScheduler( void )
{

    /* Start the timer that generates the tick ISR. */
    /* Interrupts are already disabled here */
    portSETUP_TICK_INTERRUPT();

    /* Start the first task. */
    vPortStartFirstTask();

    /* Should not get here! */
    prvTaskExitError();
    return 0;
}

void vPortEndScheduler( void )
{
    /* Not implemented in ports where there is nothing to return to
        Artificially force an assert */
    configASSERT( pdFALSE );
}

/*
 * Setup the stack of a new task so it is ready to be placed under the
 * scheduler control. The registers have to be placed on the stack in
 * the order that the port expects to find them.
 */
StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack,
                                    TaskFunction_t pxCode,
                                    void *pvParameters )
{

    /* Simulate the stack frame as it would be created by a 
        context switch interrupt. */

#if ( configENABLE_FPU == 1 )
    uint8_t idx = 30;
    pxTopOfStack -= 31;
#else
    uint8_t idx = 29;
    pxTopOfStack -= 30;
#endif /* configENABLE_FPU == 1 */

#if ( portPRELOAD_REGISTERS == 1 )
    pxTopOfStack[ idx-- ] = ( StackType_t ) portTASK_RETURN_ADDRESS;    /* R31 (LP) */
    pxTopOfStack[ idx-- ] = ( StackType_t ) pvParameters;               /* R6       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x07070707;                 /* R7       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x08080808;                 /* R8       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x09090909;                 /* R9       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x10101010;                 /* R10      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x11111111;                 /* R11      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x12121212;                 /* R12      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x13131313;                 /* R13      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x14141414;                 /* R14      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x15151515;                 /* R15      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x16161616;                 /* R16      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x17171717;                 /* R17      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x18181818;                 /* R18      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x19191919;                 /* R19      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x01010101;                 /* R1       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x02020202;                 /* R2       */
    pxTopOfStack[ idx-- ] = ( StackType_t ) portINITIAL_PSW;            /* EIPSW    */
    pxTopOfStack[ idx-- ] = ( StackType_t ) pxCode;                     /* EIPC     */
    #if (configENABLE_FPU == 1)
        pxTopOfStack[ idx-- ] = ( StackType_t ) portINITIAL_FPSR;       /* FPSR     */
    #endif /* configENABLE_FPU == 1 */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x20202020;                 /* R20      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x21212121;                 /* R21      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x22222222;                 /* R22      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x23232323;                 /* R23      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x24242424;                 /* R24      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x25252525;                 /* R25      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x26262626;                 /* R26      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x27272727;                 /* R27      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x28282828;                 /* R28      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x29292929;                 /* R29      */
    pxTopOfStack[ idx-- ] = ( StackType_t ) 0x30303030;                 /* R30 (EP) */
#else
    pxTopOfStack[ idx-- ] = ( StackType_t ) portTASK_RETURN_ADDRESS;    /* R31 (LP) */
    pxTopOfStack[ idx-- ] = ( StackType_t ) pvParameters;               /* R6       */
    idx -= 15;
    pxTopOfStack[ idx-- ] = ( StackType_t ) portINITIAL_PSW;            /* EIPSW    */
    pxTopOfStack[ idx-- ] = ( StackType_t ) pxCode;                     /* EIPC     */
    #if ( configENABLE_FPU == 1 )
        pxTopOfStack[ idx-- ] = ( StackType_t ) portINITIAL_FPSR;       /* FPSR     */
    #endif /* configENABLE_FPU == 1 */
#endif /* portPRELOAD_REGISTERS == 1 */

    /* Initialize IRQ stack */
    memset( xIRQStack, 0xA5, sizeof( xIRQStack ) );

    return pxTopOfStack;
}

/*---------------------------------------------------------------------------*/


// CUSTOM/AUX FUNCTIONS
/*---------------------------------------------------------------------------*/

void vPortSetupTimerInterrupt( void )
{
    irq_set_handler( TIMER_IRQ_ID, xPortSysTickHandler );
    irq_enable( TIMER_IRQ_ID );
    irq_set_prio( TIMER_IRQ_ID, TIMER_IRQ_PRIO );

    timer_set( uxTimerIncrementsForOneTick );

    timer_enable();
}


void xPortSysTickHandler( unsigned int dummy )
{
    (void)dummy;

    /* Increment the RTOS tick. */
    if ( xTaskIncrementTick() != pdFALSE )
    {
        /* Pend a context switch. */
        xPortSwitchRequired = pdTRUE;
    }

    timer_set( uxTimerIncrementsForOneTick );

    /* OSTM0 IRQ flag is automatically cleared by HW */
}


static void prvTaskExitError( void )
{
    /* A function that implements a task must not exit or attempt to return to
     * its caller as there is nothing to return to.  If a task wants to exit it
     * should instead call vTaskDelete( NULL ).
     *
     * Artificially force an assert() to be triggered if configASSERT() is
     * defined, then stop here so application writers can catch the error. */
    configASSERT( pdFALSE );
}
