-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Sets `always_show_dot_files = true` and `never_show_dot_files = false` in
-- `options` and returns the mutated table (`options` should be a copy, so
-- we're free to mutate it).
--
-- TODO: actually check mutability/immutability?
local function force_dot_files(options)
  options.always_show_dot_files = true
  options.never_show_dot_files = false
  return options
end

return force_dot_files
