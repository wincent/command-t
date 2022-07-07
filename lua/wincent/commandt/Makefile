# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

CCFLAGS += -Wall -Wextra -Wno-unused-parameter

ifdef DEBUG
    CCFLAGS += -DDEBUG -g -O0
else
    # As per `man 3 assert`, defining `NDEBUG` elides all `assert()` macros.
    CCFLAGS += -DNDEBUG
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
        CCFLAGS += -DLINUX
    endif
endif

LIBS = -lpthread
HDRS = $(wildcard *.h)
SRCS = $(wildcard *.c)

all: commandt.$(DLLEXT)

# Rebuild whenever CCFLAGS changes (eg. when DEBUG passed or not passed).
# See: https://stackoverflow.com/a/26147844/2103996
.PHONY: variable
define DEPEND_ON
.make/$1: variable
	@if [[ `cat .make/$1 2>&1` != '$($1)' ]]; then echo $($1) > .make/$1; fi
endef
$(eval $(call DEPEND_ON,CCFLAGS))

commandt.$(DLLEXT): $(HDRS) $(SRCS) Makefile .make/CCFLAGS
	$(CC) $(CCFLAGS) -shared -fPIC -o commandt.$(DLLEXT) $(SRCS)

.PHONY: clean

clean:
	rm -f *.$(DLLEXT)
	rm -f .make/*
	rm -rf *.so.dSYM
