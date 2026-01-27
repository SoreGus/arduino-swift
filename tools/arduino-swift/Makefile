# Makefile — ArduinoSwift host CLI (macOS/Linux)
#
# Builds the arduino-swift executable by compiling:
# - root sources (main.c, util.c, jsonlite.c)
# - all command sources under commands/**.c (including */steps/*.c)
#
# Output:
# - ./arduino-swift
# - ./build/**.o and ./build/**.d mirroring the source tree
#
# Notes:
# - Uses -MMD -MP for dependency generation.
# - Explicit include paths support include styles like:
#     #include "common/xxx.h"
#     #include "steps/step_x.h"
#     #include "verify/steps/step_x.h"
#     #include "cmd_build/steps/step_x.h"

CC ?= cc

BIN   := arduino-swift
BUILD := build

# ---- Tools ----
FIND ?= find

# ---- Sources ----
ROOT_SRCS := \
  main.c \
  util.c \
  jsonlite.c

CMD_SRCS := $(shell $(FIND) commands -type f -name '*.c' 2>/dev/null | sort)

SRCS := $(ROOT_SRCS) $(CMD_SRCS)

# ---- Objects / deps mirror directory structure under $(BUILD)/ ----
OBJS := $(patsubst %.c,$(BUILD)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

# ---- Flags ----
CFLAGS   ?= -O2 -Wall -Wextra -std=c11
CFLAGS   += -MMD -MP

CPPFLAGS += -I. \
            -Icommands \
            -Icommands/common \
            -Icommands/cmd_build \
            -Icommands/cmd_build/steps \
            -Icommands/verify \
            -Icommands/verify/steps \
            -Icommands/upload \
            -Icommands/upload/steps \
            -Icommands/monitor \
            -Icommands/monitor/steps

LDFLAGS  ?=
LDLIBS   ?=

# ---- Default target ----
all: $(BIN)

# ---- Link ----
$(BIN): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

# ---- Compile (creates nested build dirs as needed) ----
$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# ---- Clean ----
clean:
	rm -rf $(BUILD) $(BIN)

# ---- Deps ----
-include $(DEPS)

.PHONY: all clean