#include <FreeRTOS.h>
#include <FreeRTOSConfig.h>
#include <sysregs.h>
#include <gic.h>
#include <irq.h>

static uint64_t timer_step = 0;

void FreeRTOS_ClearTickInterrupt(){
    MSR(CNTV_TVAL_EL0, timer_step);
}

static void tick_handler_wrapper(unsigned id) {
    FreeRTOS_Tick_Handler();
}

void FreeRTOS_SetupTickInterrupt(){
    irq_set_handler(27, tick_handler_wrapper);
    irq_enable(27);

    uint64_t freq = MRS(CNTFRQ_EL0);
    timer_step = freq / configTICK_RATE_HZ;
    MSR(CNTV_TVAL_EL0, timer_step);
    MSR(CNTV_CTL_EL0, 1); // enable timer
}

void vApplicationIRQHandler(uint32_t ulICCIAR){ 
    gic_handle(ulICCIAR);
}

