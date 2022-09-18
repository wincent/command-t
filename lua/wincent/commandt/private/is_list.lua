-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_list = function(value)
  if type(value) ~= 'table' then
    return false
  elseif #value > 0 then
    return true
  else
    for _k, _v in pairs(value) do
      return false
    end
  end
  return true
end

return is_list
