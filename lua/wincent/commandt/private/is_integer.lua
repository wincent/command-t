-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_integer = function(numberish)
  return type(numberish) == 'number' and math.floor(numberish) == numberish
end

return is_integer
