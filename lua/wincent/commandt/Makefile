# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

CC = gcc

CCFLAGS += -Wall -Wextra -Wno-unused-parameter

ifdef DEBUG
    CCFLAGS += -DDEBUG -g -O0
else
    # As per `man 3 assert`, defining `NDEBUG` elides all `assert()` macros.
    CCFLAGS += -DNDEBUG
endif

DLLEXT := so

ifeq ($(OS),Windows_NT)
    CCFLAGS += -D WIN32
    DLLEXT := dll
else
    UNAME := $(shell uname -s)
    ifeq ($(UNAME),Darwin)
        CC = xcrun clang
        CCFLAGS += -D MACOS
    endif
    ifeq ($(UNAME),Linux)
        CCFLAGS += -D LINUX
    endif
endif

LIBS = -lpthread
HDRS = $(wildcard *.h)
SRCS = $(wildcard *.c)

all: commandt.$(DLLEXT)

commandt.$(DLLEXT): $(HDRS) $(SRCS) Makefile
	$(CC) $(CCFLAGS) -shared -fPIC -o commandt.$(DLLEXT) $(SRCS)

.PHONY: clean

clean:
	rm -f *.$(DLLEXT)
