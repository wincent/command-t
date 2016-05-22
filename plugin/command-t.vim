" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

if has('patch-7-4-1829') && get(g:, 'CommandTEngine', 'isengard') ==? 'isengard'
  call commandt#isengard#init()
else
  call commandt#mirkwood#init()
endif
