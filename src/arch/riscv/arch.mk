CROSS_COMPILE := riscv64-unknown-elf-

FREERTOS_PORT_GCC_DIR+=$(FREERTOS_DIR)/portable/GCC/RISC-V
SRC_DIRS+=$(FREERTOS_PORT_GCC_DIR)
C_SRC+=$(wildcard $(FREERTOS_PORT_GCC_DIR)/*.c)
ASM_SRC+=$(wildcard $(FREERTOS_PORT_GCC_DIR)/*.S)
INC_DIRS+=$(FREERTOS_PORT_GCC_DIR)
INC_DIRS+=$(FREERTOS_PORT_GCC_DIR)/chip_specific_extensions/RV32I_CLINT_no_extensions

ARCH_GENERIC_FLAGS = -mcmodel=medany -march=rv64imac -mabi=lp64
ARCH_GENERIC_FLAGS += -DportasmHANDLE_INTERRUPT=plic_handle -DconfigSBI=2
ARCH_ASFLAGS = 
ARCH_CFLAGS = 
ARCH_CPPFLAGS =	
ARCH_LDFLAGS = --specs=nano.specs
