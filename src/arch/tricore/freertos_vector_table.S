#define ENTRY_SIZE   (0x20)

.section ".text", "ax"

.extern vYieldHandler
.extern vUnsupportedTrap
.extern vInterruptHandler      

/* Trap Vector Table */
.balign 0x100
.global freertos_trap_table
freertos_trap_table:
    j	vUnsupportedTrap   // MMU Trap (TCN 0)

    .balign ENTRY_SIZE
    j   vUnsupportedTrap   // Internal Protection Trap (TCN 1)

    .balign ENTRY_SIZE
    j	vUnsupportedTrap   // Instruction Error (TCN 2)

    .balign ENTRY_SIZE
    j	vUnsupportedTrap   // Context Management Trap (TCN 3)

    .balign ENTRY_SIZE
    j   vUnsupportedTrap   // System Bus Error (TCN 4)

    .balign ENTRY_SIZE
    j	vUnsupportedTrap   // Assertion Trap (TCN 5)

    .balign ENTRY_SIZE
    j	vYieldHandler      // System Call (TCN 6)

    .balign ENTRY_SIZE
    j	vUnsupportedTrap   // NMI (TCN 7)

/* Interrupt Vector Table */
.balign 0x100
.global freertos_irq_table
freertos_irq_table:
    .rept   256
        .balign ENTRY_SIZE
        j vInterruptHandler
    .endr
