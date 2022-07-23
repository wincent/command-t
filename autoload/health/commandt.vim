function! s:require(condition, message)
  if a:condition
    call health#report_ok(a:message)
  else
    call health#report_error(a:message)
  endif
endfunction

function! s:commandt()
  if exists(':CommandTLoad') == 2
    CommandTLoad
  else
    return 0
  endif
  if has('ruby')
    ruby
          \ ::VIM::command
          \ "return #{$command_t && $command_t.class.respond_to?(:guard) ? 1 : 0}"
  else
    return 0
  endif
endfunction

" This checks the health of the Ruby parts of the plug-in.
" For the Lua parts, see "lua/wincent/commandt/health.lua".
function! health#commandt#check() abort
  call health#report_start('Command-T')
  call s:require(has('ruby'), 'Has Ruby support')
  call s:require(s:commandt(), 'Has working Ruby C extension')
endfunction
