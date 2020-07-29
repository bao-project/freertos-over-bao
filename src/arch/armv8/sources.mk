arch_c_srcs:= init.c psci.c irq.c timer.c port_aarch64.c
arch_s_srcs:= exceptions.S page_tables.S start.S freertos_vector_table.S

ifeq ($(GIC_VERSION),GICV3)
	arch_c_srcs+=gicv3.c
else
	arch_c_srcs+=gicv2.c
endif
