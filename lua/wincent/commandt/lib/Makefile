# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

SHELL := /bin/bash

CCFLAGS ?= -std=gnu17 -march=native -mtune=native -Wall -Wextra -Wno-unused-parameter

# Allow augmentation from the command-line with CFLAGS:
CCFLAGS += $(CFLAGS)

LBITS := $(shell getconf LONG_BIT)
ifeq ($(LBITS),64)
	# 128 M candidates.
	CCFLAGS += -DMAX_FILES_CONF=134217728
	# 128 GB.
	CCFLAGS += -DMMAP_SLAB_SIZE_CONF=137438953472
else
$(error Command-T requires a 64-bit platform; 32-bit builds are unsupported [LONG_BIT=$(LBITS)])
endif

ifdef DEBUG
	CCFLAGS += -DDEBUG -g -O0
else
	ifdef PROFILE
		CCFLAGS += -DNDEBUG -g -O3 -ffast-math
	else
		# As per `man 3 assert`, defining `NDEBUG` elides all `assert()` macros.
		CCFLAGS += -DNDEBUG -O3 -ffast-math
	endif
endif

ifeq ($(OS),Windows_NT)
	CC ?= gcc
	CCFLAGS += -DWIN32
	DLLEXT := dll
else
	DLLEXT := so
	UNAME := $(shell uname -s)
	ifeq ($(UNAME),Darwin)
		CC = xcrun clang
		CCFLAGS += -DMACOS
	endif
	ifeq ($(UNAME),Linux)
		CC ?= gcc
		CCFLAGS += -DLINUX -pthread
	endif
endif

LIBS = -lpthread
HDRS = $(wildcard *.h)
SRCS = $(wildcard *.c)

all: commandt.$(DLLEXT)

# Rebuild whenever CCFLAGS change (eg. when DEBUG/PROFILE passed or not passed).
# See: https://stackoverflow.com/a/74378629/2103996
.PHONY: .FORCE
define DEPEND_ON
.make/$1:
	@if [[ `cat .make/$1 2>&1` != "$($1)" ]]; then \
		printf '%s' "$($1)" > .make/$1; \
	fi
ifneq ("$(file <.make/$1)","$($1)")
.make/$1: .FORCE
endif
endef
$(eval $(call DEPEND_ON,CCFLAGS))

commandt.$(DLLEXT): $(HDRS) $(SRCS) Makefile .make/CCFLAGS
	$(CC) $(CCFLAGS) -shared -fPIC -o commandt.$(DLLEXT) $(SRCS)

# Test-only scorer builds. Keep these out of `all`: bin/test builds them using
# the saved CCFLAGS, so they match the extension's release/debug/sanitizer mode.
TEST_SCORE_SRCS = ../test/score.c xmalloc.c die.c
TEST_SCORE_DEPS = $(TEST_SCORE_SRCS) score.c $(HDRS) Makefile .make/CCFLAGS

.PHONY: test-score
test-score: \
	.make/score-default.$(DLLEXT) \
	.make/score-heap.$(DLLEXT) \
	.make/score-capped.$(DLLEXT) \
	.make/score-capped-heap.$(DLLEXT) \
	.make/score-late-cap-heap.$(DLLEXT)

.make/score-default.$(DLLEXT): $(TEST_SCORE_DEPS)
	$(CC) $(CCFLAGS) -shared -fPIC -I. -o $@ $(TEST_SCORE_SRCS)

.make/score-heap.$(DLLEXT): $(TEST_SCORE_DEPS)
	$(CC) $(CCFLAGS) -DSCORE_SCRATCH_STACK=2 -shared -fPIC -I. -o $@ $(TEST_SCORE_SRCS)

.make/score-capped.$(DLLEXT): $(TEST_SCORE_DEPS)
	$(CC) $(CCFLAGS) -DSCORE_CELL_CAP=0 -shared -fPIC -I. -o $@ $(TEST_SCORE_SRCS)

.make/score-capped-heap.$(DLLEXT): $(TEST_SCORE_DEPS)
	$(CC) $(CCFLAGS) -DSCORE_CELL_CAP=0 -DSCORE_SCRATCH_STACK=2 -shared -fPIC -I. -o $@ $(TEST_SCORE_SRCS)

.make/score-late-cap-heap.$(DLLEXT): $(TEST_SCORE_DEPS)
	$(CC) $(CCFLAGS) -DSCORE_CELL_CAP=4 -DSCORE_SCRATCH_STACK=2 -shared -fPIC -I. -o $@ $(TEST_SCORE_SRCS)

.PHONY: clean
clean:
	rm -f *.$(DLLEXT)
	rm -rf .make/*.$(DLLEXT).dSYM
	rm -f .make/*
	rm -rf *.so.dSYM
