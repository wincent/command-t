# SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

LUA_DIR = lua/wincent/commandt/lib

.PHONY: build
build:
	$(MAKE) -C $(LUA_DIR)

.PHONY: check
check:
	$(MAKE) clean build test
	bin/check-format
	bin/check-tag

.PHONY: help
help:
	@echo "make build    compile"
	@echo "make check    run prerelease checks (clean, build, run tests, check style, check tag)"
	@echo "make clean    remove build artifacts"
	@echo "make help     show this help"
	@echo "make test     run tests"

.PHONY: test
test:
	bin/spec
	bin/test

.PHONY: clean
clean:
	$(MAKE) -C $(LUA_DIR) clean
