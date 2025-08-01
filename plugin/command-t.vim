" SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
" SPDX-License-Identifier: BSD-2-Clause

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

let s:prefers_ruby=get(g:, 'CommandTPreferredImplementation', 'unset') ==? 'ruby'
let s:prefers_lua=get(g:, 'CommandTPreferredImplementation', 'unset') ==? 'lua'
let s:has_preference=s:prefers_ruby || s:prefers_lua

if has('nvim') && !s:has_preference
  let s:lua_suppression=[
        \   ['To select Ruby:', "vim.g.CommandTPreferredImplementation = 'ruby'"],
        \   ['To select Lua (the default):', "require('wincent.commandt').setup()"]
        \ ]
  let s:vimscript_suppression=[
        \   ['To select Ruby:', "let g:CommandTPreferredImplementation='ruby'"],
        \   ['To select Lua (the default):', "let g:CommandTPreferredImplementation='lua'"]
        \ ]
  let s:suppression=exists('$MYVIMRC') && match($MYVIMRC, '\c\.lua') > 0
        \ ? s:lua_suppression
        \ : s:vimscript_suppression
  echohl WarningMsg
  echo 'Notice'
  echo '------'
  echo "\n"
  echo 'Starting with Command-T version 6.0, Command-T ships with a new core'
  echo 'written in Lua (rather than Ruby). The new core supports only Neovim'
  echo '(rather than Vim and Neovim), and is faster and more robust.'
  echo "\n"
  echo 'See `:help command-t-upgrading` for information on how to choose'
  echo 'between the Lua and the Ruby implementations.'
  echo "\n"
  echo 'To suppress this warning, add one of these to your vimrc:'
  echo "\n"
  for [s:label, s:instruction] in s:suppression
    echo '  ' . s:label
    echo '    ' . s:instruction
    echo "\n"
  endfor
  echohl none
  let s:prefers_lua=1
endif

if empty(&switchbuf)
  set switchbuf=usetab
endif

if s:prefers_ruby
  command! -nargs=? -complete=dir CommandT call commandt#FileFinder(<q-args>)
  command! CommandTBuffer call commandt#BufferFinder()
  command! CommandTCommand call commandt#CommandFinder()
  command! CommandTFlush call commandt#Flush()
  command! CommandTHelp call commandt#HelpFinder()
  command! CommandTHistory call commandt#HistoryFinder()
  command! CommandTJump call commandt#JumpFinder()
  command! CommandTLine call commandt#LineFinder()
  command! CommandTLoad call commandt#Load()
  command! CommandTMRU call commandt#MRUFinder()
  command! CommandTSearch call commandt#SearchFinder()
  command! CommandTTag call commandt#TagFinder()
  command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)
else
  command! -nargs=? -complete=dir KommandT call commandt#FileFinder(<q-args>)
  command! KommandTBuffer call commandt#BufferFinder()
  command! KommandTCommand call commandt#CommandFinder()
  command! KommandTHelp call commandt#HelpFinder()
  command! KommandTSearch call commandt#SearchFinder()
  command! KommandTHistory call commandt#HistoryFinder()
  command! KommandTJump call commandt#JumpFinder()
  command! KommandTLine call commandt#LineFinder()
  command! KommandTTag call commandt#TagFinder()

  " Not implemented on the Lua side yet, so these ones continue to use "CommandT" prefix:
  command! CommandTFlush call commandt#Flush()
  command! CommandTLoad call commandt#Load()
  command! CommandTMRU call commandt#MRUFinder()

  command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)
endif

" These ones not implemented on the Lua side yet:
nnoremap <silent> <Plug>(CommandTMRU) :CommandTMRU<CR>

if s:prefers_ruby
  nnoremap <silent> <Plug>(CommandT) :CommandT<CR>
  nnoremap <silent> <Plug>(CommandTBuffer) :CommandTBuffer<CR>
  nnoremap <silent> <Plug>(CommandTCommand) :CommandTCommand<CR>
  nnoremap <silent> <Plug>(CommandTHelp) :CommandTHelp<CR>
  nnoremap <silent> <Plug>(CommandTLine) :CommandTLine<CR>
  nnoremap <silent> <Plug>(CommandTTag) :CommandTTag<CR>

  if !hasmapto('<Plug>(CommandT)') && maparg('<Leader>t', 'n') ==# ''
    nmap <unique> <Leader>t <Plug>(CommandT)
  endif

  if !hasmapto('<Plug>(CommandTBuffer)') && maparg('<Leader>b', 'n') ==# ''
    nmap <unique> <Leader>b <Plug>(CommandTBuffer)
  endif

  if has('jumplist')
    if !hasmapto('<Plug>(CommandTJump)') && maparg('<Leader>j', 'n') ==# ''
      nmap <unique> <Leader>j <Plug>(CommandTJump)
    endif
  endif
endif
