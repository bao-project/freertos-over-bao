ARCH_GENERIC_FLAGS += -DGUEST

ARCH_SUB?=aarch64
arch_sub_dir:=$(cur_dir)/$(ARCH_SUB)
-include $(arch_sub_dir)/arch_sub.mk
SRC_DIRS+=$(arch_sub_dir)
INC_DIRS+=$(arch_sub_dir)/inc
-include $(arch_sub_dir)/sources.mk
C_SRC+=$(addprefix $(arch_sub_dir)/, $(sub_arch_c_srcs))
ASM_SRC+=$(addprefix $(arch_sub_dir)/, $(sub_arch_s_srcs))
