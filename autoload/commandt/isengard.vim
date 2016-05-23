" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

let s:script_directory=expand('<sfile>:p:h')

" Set up the new async implementation of the Command-T engine -- successor to
" "mirkwood" -- codenamed "isengard".
function! commandt#isengard#init() abort
  let l:daemon_path=resolve(s:script_directory . '/../../ruby/command-t/commandtd')

  if exists('$TMPDIR')
    let l:default_client_log_file=simplify($TMPDIR . '/clog')
    let l:default_server_log_file=simplify($TMPDIR . '/slog')
  else
    let l:default_client_log_file='/tmp/clog'
    let l:default_server_log_file='/tmp/clog'
  endif
  let l:client_log_file=get(g:, 'CommandTClientLog', l:default_client_log_file)
  let l:server_log_file=get(g:, 'CommandTServerLog', l:default_server_log_file)
  if !empty(l:client_log_file)
    call ch_logfile(l:client_log_file, 'w')
  endif
  if !empty(l:server_log_file)
    let s:job=job_start([l:daemon_path, '--logfile=' . l:server_log_file, '--vim-pid=' . getpid()])
  else
    let s:job=job_start([l:daemon_path, '--vim-pid=' . getpid()])
  endif
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
