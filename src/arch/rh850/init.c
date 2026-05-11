#include "FreeRTOS.h"
#include <intc.h>
#include <srs.h>

void arch_init()
{
#if ( configENABLE_FPU == 1 )
    /* Set PSW.CU1-0 */
    unsigned long psw = srs_psw_read() | PSW_CU1 | PSW_CU0;
    srs_psw_write(psw);
#endif

    intc_init();
}