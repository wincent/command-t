" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

let s:script_directory=expand('<sfile>:p:h')

" Set up the new async implementation of the Command-T engine -- successor to
" "mirkwood" -- codenamed "isengard".
function! commandt#isengard#init() abort
  let l:daemon_path=resolve(s:script_directory . '/../../ruby/command-t/commandtd')

  " Include the PID of the parent (this Vim process) to make `ps` output more
  " useful.
  let g:this=job_start([l:daemon_path, '--vim-pid=' . getpid()])
endfunction
