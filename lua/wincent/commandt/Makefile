###
# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

CC = gcc

CCFLAGS += -Wall -Wextra -Wno-unused-parameter

ifdef DEBUG
    CCFLAGS += -DDEBUG
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

commandt.$(DLLEXT): $(HDRS) $(SRCS) Makefile
	$(CC) $(CCFLAGS) -shared -fPIC -o commandt.$(DLLEXT) $(SRCS)
