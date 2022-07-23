" SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
" SPDX-License-Identifier: BSD-2-Clause

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

let s:prefers_ruby=get(g:, 'CommandTPreferredImplementation', 'unset') ==? 'ruby'
let s:prefers_lua=get(g:, 'CommandTPreferredImplementation', 'unset') ==? 'lua'
let s:has_preference=s:prefers_ruby || s:prefers_lua

if has('nvim') &&
      \ !s:has_preference &&
      \ !get(g:, 'CommandTSuppressRubyDeprecationWarning', 0)
  let s:lua_suppression = 'vim.g.CommandTSuppressRubyDeprecationWarning = 1'
  let s:vimscript_suppression = 'let g:CommandTSuppressRubyDeprecationWarning=1'
  echohl WarningMsg
  echo 'Notice'
  echo '------'
  echo "\n"
  echo 'Starting with Command-T version 6.0, Command-T has been rewritten in'
  echo 'Lua (rather than Ruby), and supports only Neovim (rather than Vim and'
  echo 'Neovim). The new version is faster and more robust.'
  echo "\n"
  echo 'See `:help command-t-upgrading` for information on how to choose'
  echo 'between the Lua and the Ruby implementations.'
  echo "\n"
  echo 'To suppress this warning, add this to your vimrc:'
  echo "\n"
  if exists('$MYVIMRC') && match($MYVIMRC, '\c\.lua') > 0
    echo '    ' . s:lua_suppression
  else
    echo '    ' . s:vimscript_suppression
  endif
  echo "\n"
  if exists('$MYVIMRC')
    echo 'Your vimrc is currently at:'
    echo "\n"
    echo '   ' . $MYVIMRC
    echo "\n"
    let s:response=trim(input('Would you like to add this line to it now? (y/n) '))
    echo "\n"
    if s:response ==? 'y' || s:response ==? 'ye' || s:response ==? 'yes'
      if match($MYVIMRC, '\c\.lua') > 0
        call writefile([s:lua_suppression], $MYVIMRC, 'a')
      else
        call writefile([s:vimscript_suppression], $MYVIMRC, 'a')
      end
    endif
  endif
  echohl none
  " BUG: highlighting is all messed up after this... (until next focus-gained
  " event; probably specific to my local set-up)
else
  let s:prefers_ruby=1
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
  command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)'
else
  command! -nargs=? -complete=dir KommandT call commandt#FileFinder(<q-args>)
  command! KommandTBuffer call commandt#BufferFinder()
  command! KommandTHelp call commandt#HelpFinder()

  " Not implemented on the Lua side yet, so these ones continue to use "CommandT" prefix:
  command! CommandTCommand call commandt#CommandFinder()
  command! CommandTFlush call commandt#Flush()
  command! CommandTHistory call commandt#HistoryFinder()
  command! CommandTJump call commandt#JumpFinder()
  command! CommandTLine call commandt#LineFinder()
  command! CommandTLoad call commandt#Load()
  command! CommandTMRU call commandt#MRUFinder()
  command! CommandTSearch call commandt#SearchFinder()
  command! CommandTTag call commandt#TagFinder()

  command! -nargs=+ CommandTOpen call commandt#GotoOrOpen(<q-args>)'
endif

" These ones not implemented on the Lua side yet:
nnoremap <silent> <Plug>(CommandTCommand) :CommandTCommand<CR>
nnoremap <silent> <Plug>(CommandTJump) :CommandTJump<CR>
nnoremap <silent> <Plug>(CommandTLine) :CommandTLine<CR>
nnoremap <silent> <Plug>(CommandTMRU) :CommandTMRU<CR>
nnoremap <silent> <Plug>(CommandTSearch) :CommandTSearch<CR>
nnoremap <silent> <Plug>(CommandTTag) :CommandTTag<CR>
nnoremap <silent> <Plug>(CommandTHistory) :CommandTHistory<CR>

if s:prefers_ruby
  nnoremap <silent> <Plug>(CommandT) :CommandT<CR>
  nnoremap <silent> <Plug>(CommandTBuffer) :CommandTBuffer<CR>
  nnoremap <silent> <Plug>(CommandTHelp) :CommandTHelp<CR>

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
