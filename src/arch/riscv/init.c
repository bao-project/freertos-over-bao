#include <stdint.h>
#include <cpu.h>
#include <page_tables.h>
#include <plic.h>
#include <sbi.h>
#include <csrs.h>

#include <stdio.h>

int hart_id;
extern void _start();

void arch_init(uint64_t cpu_id){
    hart_id = cpu_id;
    pt_init();
    plic_init();   
}
