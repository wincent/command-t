" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

let s:script_directory=expand('<sfile>:p:h')

" Set up the new async implementation of the Command-T engine -- successor to
" "mirkwood" -- codenamed "isengard".
function! commandt#isengard#init() abort
  let l:daemon_path=resolve(s:script_directory . '/../../ruby/command-t/bin/commandtd')

  let l:client_log_file=get(g:, 'CommandTClientLog', '')
  let l:server_log_file=get(g:, 'CommandTServerLog', '')
  if !empty(l:client_log_file)
    call ch_logfile(l:client_log_file, 'w')
  endif
  if !empty(l:server_log_file)
    let s:job=job_start([l:daemon_path, '--logfile=' . l:server_log_file, '--vim-pid=' . getpid()])
  else
    let s:job=job_start([l:daemon_path, '--vim-pid=' . getpid()])
  endif
  let s:channel=job_getchannel(s:job)

  call ch_evalraw(s:channel, json_encode({'cd': getcwd()}) . "\n")
  let g:CommandTResult=ch_evalraw(s:channel, json_encode({'match': 'commandt'}) . "\n")
endfunction
