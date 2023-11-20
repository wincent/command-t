# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

SHELL := /bin/bash

CCFLAGS += -Wall -Wextra -Wno-unused-parameter

LBITS := $(shell getconf LONG_BIT)
ifeq ($(LBITS),64)
	# 128 M candidates.
	CCFLAGS += -DMAX_FILES_CONF=134217728
	# 128 GB.
	CCFLAGS += -DMMAP_SLAB_SIZE_CONF=137438953472
else
	# 32 M candidates.
	CCFLAGS += -DMAX_FILES_CONF=33554432
	# 32 GB.
	CCFLAGS += -DMMAP_SLAB_SIZE_CONF=34359738368
endif

ifdef DEBUG
	CCFLAGS += -DDEBUG -g -O0
else
	# As per `man 3 assert`, defining `NDEBUG` elides all `assert()` macros.
	# May also want to consider going `-Ofast` instead of `-O3`.
	CCFLAGS += -DNDEBUG -O3
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

MIMALLOC_BASE = vendor/github/microsoft/mimalloc
MIMALLOC_INCLUDE = $(MIMALLOC_BASE)/include
MIMALLOC_SRC = $(MIMALLOC_BASE)/src
MIMALLOC_OVERRIDE = mimalloc-override.o

ifdef USE_MIMALLOC
	MIMALLOC_HDRS = $(wildcard $(MIMALLOC_INCLUDE)/*.h)
	MIMALLOC_SRCS = $(wildcard $(MIMALLOC_SRC)/*.c)
	MALLOC_OBJ = $(MIMALLOC_OVERRIDE)
endif

all: commandt.$(DLLEXT)

# Rebuild whenever CCFLAGS changes (eg. when DEBUG passed or not passed).
# See: https://stackoverflow.com/a/26147844/2103996
.PHONY: variable
define DEPEND_ON
.make/$1: variable
	@if [[ `cat .make/$1 2>&1` != '$($1)' ]]; then echo $($1) > .make/$1; fi
endef
$(eval $(call DEPEND_ON,CCFLAGS))
$(eval $(call DEPEND_ON,USE_MIMALLOC))

$(MIMALLOC_OVERRIDE): $(MIMALLOC_HDRS) $(MIMALLOC_SRCS) Makefile .make/CCFLAGS
	$(CC) $(CCFLAGS) -I$(MIMALLOC_INCLUDE) -c -fPIC -o $(MIMALLOC_OVERRIDE) $(MIMALLOC_SRC)/static.c

commandt.$(DLLEXT): $(HDRS) $(SRCS) $(MIMALLOC_OVERRIDE) Makefile .make/CCFLAGS .make/USE_MIMALLOC
	$(CC) $(CCFLAGS) -shared -fPIC -o commandt.$(DLLEXT) $(MALLOC_OBJ) $(SRCS)

.PHONY: clean
clean:
	rm -f *.$(DLLEXT)
	rm -f *.o
	rm -f .make/*
	rm -rf *.so.dSYM
