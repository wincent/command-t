-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

return function(spec)
  if type(spec) == 'table' then
    assert(_G.vim == nil)
    _G.vim = {
      fn = {},
    }
    for key, value in pairs(spec) do
      if key == 'fn' then
        if type(value) == 'table' then
          for inner_key, inner_value in pairs(value) do
            if inner_key == 'fnamemodify' then
              if inner_value then
                require('wincent.commandt.private.mocks.vim.fn.fnamemodify').setup()
              else
                vim.fn.fnamemodify = nil
              end
            else
              error('unsupported key: fn.' .. inner_key)
            end
          end
        else
          error('unsupported type for "fn": ' .. type(inner_value))
        end
      elseif key == 'inspect' then
        if value then
          require('wincent.commandt.private.mocks.vim.inspect').setup()
        else
          vim.inspect = nil
        end
      elseif key == 'iter' then
        if value then
          require('wincent.commandt.private.mocks.vim.iter').setup()
        else
          vim.iter = nil
        end
      elseif key == 'startswith' then
        if value then
          require('wincent.commandt.private.mocks.vim.startswith').setup()
        else
          vim.startswith = nil
        end
      else
        error('unsupported key: ' .. key)
      end
    end
  elseif spec == false then
    -- Remove mock.
    _G.vim = nil
  else
    error('unsupported spec: ' .. type(spec))
  end
end
