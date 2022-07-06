-- SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local scanner = {}

-- TODO: think about lazy-loading these when actually needed
scanner.buffer = require('wincent.commandt.scanner.buffer')
scanner.help = require('wincent.commandt.scanner.help')

return scanner
