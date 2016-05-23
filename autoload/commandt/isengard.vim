" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

let s:script_directory=expand('<sfile>:p:h')

" Set up the new async implementation of the Command-T engine -- successor to
" "mirkwood" -- codenamed "isengard".
function! commandt#isengard#init() abort
  let l:daemon_path=resolve(s:script_directory . '/../../ruby/command-t/commandtd')

  call ch_logfile('/tmp/clog', 'w')

  " Include the PID of the parent (this Vim process) to make `ps` output more
  " useful.
  let s:job=job_start([l:daemon_path, '--vim-pid=' . getpid()], {
        \ })
  let s:channel=job_getchannel(s:job)

  let l:r=ch_evalraw(s:channel, json_encode({"this": "is a test 1"}) . "\n")
  echomsg "message <" . l:r . ">"
  let l:r=ch_evalraw(s:channel, json_encode({"this": "is a test 2"}) . "\n")
  echomsg "message <" . l:r . ">"
  let l:r=ch_evalraw(s:channel, json_encode({"this": "is a test 3"}) . "\n")
  echomsg "message <" . l:r . ">"
  let l:r=ch_evalraw(s:channel, json_encode({"this": "is a test 4"}) . "\n")
  echomsg "message <" . l:r . ">"
  let l:r=ch_evalraw(s:channel, json_encode({"this": "is a test 5"}) . "\n")
  echomsg "message <" . l:r . ">"
endfunction
