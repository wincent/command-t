" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)

if empty(&switchbuf)
  set switchbuf=usetab
endif

call commandt#mirkwood#init()
