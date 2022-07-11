#!/bin/bash
#
# SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

REPO_ROOT="${BASH_SOURCE%/*}/.."

cd "$REPO_ROOT"

find lua -type f -path '*/test/*' -name '*.lua' -print0 | \
  xargs -0 bin/test.lua
