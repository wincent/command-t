-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local c = require('wincent.commandt.private.lib.c')

local function print_scanner(scanner)
  c.commandt_print_scanner(scanner)
end

return print_scanner
