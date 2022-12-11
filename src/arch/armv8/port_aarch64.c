#include <FreeRTOS.h>
#include <FreeRTOSConfig.h>
#include <portmacro.h>
#include <sysregs.h>
#include <gic.h>
#include <irq.h>

static uint64_t timer_step = 0;

void FreeRTOS_ClearTickInterrupt(){
    sysreg_cntv_tval_el0_write(timer_step);
}

static void tick_handler_wrapper(unsigned id) {
    FreeRTOS_Tick_Handler();
}

void FreeRTOS_SetupTickInterrupt(){
    irq_set_handler(27, tick_handler_wrapper);
    irq_enable(27);
    irq_set_prio(27, portLOWEST_USABLE_INTERRUPT_PRIORITY << portPRIORITY_SHIFT);

    uint64_t freq = sysreg_cntfrq_el0_read();
    timer_step = freq / configTICK_RATE_HZ;
    sysreg_cntv_tval_el0_write(timer_step);
    sysreg_cntv_ctl_el0_write(1); // enable timer
}

void vApplicationIRQHandler(uint32_t ulICCIAR){ 
    irq_handle(ulICCIAR);
}

