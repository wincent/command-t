-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local c = require('wincent.commandt.private.lib.c')

local function matcher_run(matcher, needle)
  return c.commandt_matcher_run(matcher, needle)
end

return matcher_run
