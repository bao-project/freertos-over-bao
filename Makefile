# 
# Bao, a Lightweight Static Partitioning Hypervisor 
#
# Copyright (c) Bao Project (www.bao-project.org), 2019-
#
# Authors:
#      Jose Martins <jose.martins@bao-project.org>
#      Sandro Pinto <sandro.pinto@bao-project.org>
#
# Bao is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License version 2 as published by the Free
# Software Foundation, with a special exception exempting guest code from such
# license. See the COPYING file in the top-level directory for details. 
#
#

NAME := freertos
OPT_LEVEL = 3
DEBUG_LEVEL = 3

ifneq ($(MAKECMDGOALS), clean)
ifeq ($(PLATFORM),)
$(error Undefined platform)
endif
endif

SRC_DIR:=./src
BMRT_SRC_DIR:=./src/baremetal-runtime/src
BUILD_DIR:=build/$(PLATFORM)
TARGET:=$(BUILD_DIR)/$(NAME)
SRC_DIRS:=$(SRC_DIR)

-include $(SRC_DIR)/sources.mk
C_SRC+=$(addprefix $(SRC_DIR)/, $(src_c_srcs))

FREERTOS_DIR:=$(SRC_DIR)/freertos
FREERTOS_MEMMNG_DIR:=$(FREERTOS_DIR)/portable/MemMang
SRC_DIRS+=$(FREERTOS_DIR) $(FREERTOS_MEMMNG_DIR)
C_SRC+=$(wildcard $(FREERTOS_DIR)/*.c)
C_SRC+=$(FREERTOS_MEMMNG_DIR)/heap_4.c

BMRT_CORE_DIR:=$(BMRT_SRC_DIR)/core
SRC_DIRS+=$(BMRT_CORE_DIR)
-include $(BMRT_CORE_DIR)/sources.mk
C_SRC+=$(addprefix $(BMRT_CORE_DIR)/, $(core_c_srcs))

PLATFORM_DIR:=$(BMRT_SRC_DIR)/platform/$(PLATFORM)
ifeq ($(wildcard $(PLATFORM_DIR)),)
$(error unsupported platform $(PLATFORM))
endif
SRC_DIRS+=$(PLATFORM_DIR)
-include $(PLATFORM_DIR)/plat.mk
-include $(PLATFORM_DIR)/sources.mk
C_SRC+=$(addprefix $(PLATFORM_DIR)/, $(plat_c_srcs))
ASM_SRC+=$(addprefix $(PLATFORM_DIR)/, $(plat_s_srcs))

DRIVERS_DIR:=$(addprefix $(BMRT_SRC_DIR)/drivers/, $(drivers))
SRC_DIRS+=$(DRIVERS_DIR)
-include $(addprefix $(DRIVERS_DIR), /sources.mk)
C_SRC+=$(addprefix $(BMRT_SRC_DIR)/drivers/, $(driver_c_srcs))
ASM_SRC+=$(addprefix $(BMRT_SRC_DIR)/drivers/, $(driver_s_srcs))

ARCH_DIR:=$(SRC_DIR)/arch/$(ARCH)
BMRT_ARCH_DIR:= $(BMRT_SRC_DIR)/arch/$(ARCH)
ifeq ($(wildcard $(ARCH_DIR)),)
$(error unsupported architecture $(ARCH))
endif
SRC_DIRS+= $(ARCH_DIR) $(BMRT_ARCH_DIR)
-include $(BMRT_ARCH_DIR)/arch.mk
-include $(BMRT_ARCH_DIR)/sources.mk
bmrt_arch_c_srcs:=$(arch_c_srcs)
bmrt_arch_s_srcs:=$(arch_s_srcs)
C_SRC+=$(addprefix $(BMRT_ARCH_DIR)/, $(bmrt_arch_c_srcs))
ASM_SRC+=$(addprefix $(BMRT_ARCH_DIR)/, $(bmrt_arch_s_srcs))
arch_c_srcs:=
arch_s_srcs:=
-include $(ARCH_DIR)/arch.mk
-include $(ARCH_DIR)/sources.mk
C_SRC+=$(addprefix $(ARCH_DIR)/, $(arch_c_srcs))
ASM_SRC+=$(addprefix $(ARCH_DIR)/, $(arch_s_srcs))

INC_DIRS+=$(realpath  $(addsuffix /inc, $(SRC_DIRS)) \
	$(addsuffix /include, $(SRC_DIRS)))

LD_FILE:= $(BMRT_SRC_DIR)/linker.ld
GEN_LD_FILE:= $(BUILD_DIR)/linker.ld
OBJS = $(C_SRC:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o) \
	$(ASM_SRC:$(SRC_DIR)/%.S=$(BUILD_DIR)/%.o)
DEPS = $(OBJS:%=%.d) $(GEN_LD_FILE).d
DIRS:=$(sort $(dir $(OBJS) $(DEPS)))

CC=$(CROSS_COMPILE)gcc
AS=$(CROSS_COMPILE)as
LD=$(CROSS_COMPILE)ld
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump

GENERIC_FLAGS = $(ARCH_GENERIC_FLAGS) -O$(OPT_LEVEL) -g$(DEBUG_LEVEL) -static
ASFLAGS = $(GENERIC_FLAGS) $(ARCH_ASFLAGS) 
CFLAGS = $(GENERIC_FLAGS) $(ARCH_CFLAGS) 
CPPFLAGS =	$(ARCH_CPPFLAGS) $(addprefix -I, $(INC_DIRS)) -MD -MF $@.d
LDFLAGS = $(GENERIC_FLAGS) $(ARCH_LDFLAGS) -nostartfiles 
all: $(TARGET).bin

ifneq ($(MAKECMDGOALS), clean)
-include $(DEPS)
endif

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).elf: $(OBJS) $(GEN_LD_FILE)
	$(CC) $(LDFLAGS) -T$(GEN_LD_FILE) $(OBJS) -o $@
	$(OBJDUMP) -S $@ > $(TARGET).asm
	$(OBJDUMP) -x -d --wide $@ > $(TARGET).lst

$(BUILD_DIR):
	mkdir -p $@

$(OBJS): | $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	$(CC) $(ASFLAGS) $(CPPFLAGS) -c $< -o $@

$(GEN_LD_FILE): $(LD_FILE)
	$(CC) $(CPPFLAGS) -E -x assembler-with-cpp $< | grep "^[^#;]" > $@

.SECONDEXPANSION:

$(OBJS) $(DEPS): | $$(@D)/

$(DIRS):
	mkdir -p $@


clean:
	@rm -rf build
	@rm -f *.elf
	@rm -f *.bin	
	@rm -f *.asm
	@rm -f *.lst

.PHONY: all clean
