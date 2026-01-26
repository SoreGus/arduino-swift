CC ?= cc

# Output
BIN := arduino-swift
BUILD := build

# Sources
SRCS := \
  main.c \
  cmd_verify.c \
  cmd_build.c \
  cmd_upload.c \
  cmd_monitor.c \
  util.c \
  jsonlite.c

OBJS := $(SRCS:%.c=$(BUILD)/%.o)
DEPS := $(OBJS:.o=.d)

# Flags
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
CPPFLAGS += -I.
CFLAGS   += -MMD -MP
LDFLAGS  ?=
LDLIBS   ?=

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)

$(BUILD)/%.o: %.c | $(BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD) $(BIN)

-include $(DEPS)

.PHONY: all clean
