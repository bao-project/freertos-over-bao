
#include <stdint.h>
#include <psci.h>
#include <gic.h>

void _start();

void arch_init(uint64_t cpuid){
    gic_init();
}
