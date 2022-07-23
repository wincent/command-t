#!/bin/bash
#
# SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

REPO_ROOT="${BASH_SOURCE%/*}/.."

# Must `cd` to root in order for `stylua.toml` to get picked up.
cd "$REPO_ROOT"

stylua .

npx -y prettier --write "**/*.md"

# TODO: Figure out how to use: /System/Volumes/Data/opt/homebrew/Cellar/llvm/13.0.1_1/bin/clang-format
# ... it has a ridiculous number of options
