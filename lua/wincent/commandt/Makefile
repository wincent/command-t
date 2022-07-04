# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

CC = gcc

CCFLAGS += -Wall -Wextra -Wno-unused-parameter

ifdef DEBUG
    CCFLAGS += -DDEBUG -g
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
