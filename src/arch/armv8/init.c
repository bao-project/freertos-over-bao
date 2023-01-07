
#include <gic.h>
#include <sysregs.h>

void arch_init(){
    extern void _freertos_vector_table();
    sysreg_vbar_el1_write((uintptr_t)_freertos_vector_table);
    gic_init();
}
