-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- A lazy fallback wrapper (to avoid the cost of scanning until actually needed)
-- around the built-in file finder.
return function(finder, directory, options)
  return function()
    finder.fallback = require('wincent.commandt.private.finders.file')(directory ~= '' and directory or '.', options)
    return finder.fallback, 'fallback'
  end
end
