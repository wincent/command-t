# Life-cycle of a Command-T search

"finders" use "scanners" to generate a list of haystacks to search (usually but not always files).

There are two generic classes of "finder", each paired with a corresponding generic class of scanner:

1. **"List"-based finders and scanners.** These take a list of candidate haystacks, like a list of buffers, a list of help tags, or a list of search patterns. These are accessed by commands like `:CommandTBuffer`, `:CommandTHelp`, and `:CommandTSearch`.
2. **"Exec"-based finders and scanners.** These run a command to generate the list of candidate haystacks. These are accessed by commands like `:CommandTGit` and `:CommandTRipgrep`.

Each instance of a list or exec-based finder is defined using a Lua table. Finder definitions are found under `finders`, and specify either `candidates` (a list of candidates, or a function that returns such a list) or `command` (a command string, or a function that returns such a string).

There are also two specialised "finder" and "scanner" pairs:

1. **The built-in "file" finder.** This uses POSIX APIs to traverse the filesystem and generate a list of candidates.
2. **The watchman finder.** This communicates with watchman using its binary protocol to obtain a list of candidates.

These finders are hard-coded in the Command-T source code as functions.

In the following discussion, note that there are a few sets of confusing, overlapping, or overloading terms that would make a good target for refactoring:

- "open", "on_open": used at various layers of abstraction for configuration key names, callbacks, parameters, and so on.
- "config" vs "options": used to describe user-supplied settings, defaults, and also function-level parameters.

## List-based finder life-cycle

1. (Optional) User configures a mapping in their personal config (eg. `vim.keymap.set('n', '<Leader>b', '<Plug>(CommandTBuffer)')`)
2. (Optional) User uses the mapping, which passes through the built-in `<Plug>` mapping to a command (eg. `vim.keymap.set('n', '<Plug>(CommandTBuffer)', ':CommandTBuffer<CR>', { silent = true })`)
3. The command invokes the `commandt.finder` function defined in `init.lua`, passing `'buffer'` as a parameter:

   ```
   vim.api.nvim_create_user_command(CommandTBuffer, function()
     require('wincent.commandt').finder('buffer')
   end, {
     nargs = 0,
   })
   ```

4. `commandt.finder()` takes two params, a finder `name`, and an optional `directory` (not passed in the case of `:CommandTBuffer`, `:CommandTHelp`, `:CommandTHistory`, `:CommandTJump`, `:CommandTLine`, `:CommandTSearch`, or `:CommandTTag`, but passed in the case of `:CommandTFd`, `:CommandTFind`, `:CommandTGit`, and `:CommandTRipgrep`).
   1. It looks up the finder config under the `name` key (`'buffer'`, for example) of the user's settings (obtained via a call to `commandt.options()`, which returns a _copy_ of the user's settings, or falls back to the defaults if there are no explicit user settings).
   2. If the config defines an `options` callback, it calls the callback with the existing options so that it has an opportunity to transform those options, and then sanitizes them. This is used by several finders to force the display of dotfiles (ie. by unconditionally setting `always_show_dot_files` to `true`, and `never_show_dot_files` to `false`); specifically, the `'buffer'`, `'help'`, `'history'`, `'jump'`, `'line'`, `'search'`, and `'tag'` finders.
   3. If the config defines an `on_directory` callback, it calls the callback with the directory to give it the opportunity to transform the directory. This is used by finders which change their root directory based on the `commandt.traverse` setting; if no directory is provided, and the user settings require it, the callback will attempt to infer an appropriate directory, using the current working directory as a fallback. Finders which use `on_directory` include `'fd'`, `'find'`, `'git'`, and `'rg'`.
   4. It prepares an `open` callback with signature `open(item, ex_command)` and assigns it back to the `options` object that will be passed into the `finders.list` or `finders.exec` implementation, and also into `ui.show()`. This `open` callback will in turn forward to the `open` implementation specified in the config, if provided, otherwise falling back to `sbuffer(item, ex_command)` (which tries to intelligently pick the right place to open the requested buffer). Finders which specify a custom `'open'` in their config include `'fd'`, `'find'`, `'git'`, and `'rg'`; which all pass in an `on_open(item, ex_command, directory, _options, _context)` implementation which uses `sbuffer()` to open a relativized path (ie. `sbuffer(relativize(directory, item), ex_command)`). In contrast, the `'help'`, `'history'`, `'line'`, `'search'`, and `'tag'` finders define totally custom open callbacks. Finally, the `'buffer'` and `'jump'` finders define nothing, which means they use the fallback.
   5. If the finder config provides a `candidates` field, it obtains the actual list finder and context by passing in the `directory`, `config.candidates`, and `options`. Otherwise, it must contain a `command` field and it obtains a command finder passing in `directory`, `config.command`, `options`, and `name` (the `name` is used to look up finder-specific settings in the `options`).
   6. If the finder config provides a `fallback` field set to `true`, it adds the fallback finder to the `finder` object, passing in the original `finder`, `'.'`, and `options` (this fallback finder is a lazy wrapper around the built-in file finder, which gets invoked if the primary finder fails; `'.'` is always correct because all callers `pushd` into the target directory before scanning).
   7. It invokes `ui.show()`, passing in the `finder` and `options`, merging in three additional settings: `name`, `mode` (`mode` is `'virtual'`, `'file'` or `nil`), and an `on_close` callback set to `config.on_close`. Finders which actually specify an `on_close` are `'fd'`, `'find'`, `'git'`, `'rg'`, and the built-in file finders; they all use `popd` for this purpose, to reset to the original working directory in case the user specified a temporary directory as an argument to those finders (the watchman finder doesn't need this as it does not change into a temporary directory even when the user specifies a directory argument).
5. `ui.show()` sets some module-level state based on the passed in `finder`, `options.on_close`, and `options.on_open`.
6. It calls `MatchListing.new()`, passing in specific options, and then `match_listing:show()`.
7. It calls `Prompt.new()`, again passing in specific options, including passing `ui.open` via the `on_open` property, then `prompt:show()`.
   1. `Prompt.new()` captures various settings, including `on_open` and `mappings`. It creates a window with `Window.new()` and `self._window:show()`, and sets up mappings inside that window with `self._window:map()`. When the user chooses to open a selection via a mapping, the prompt will call the `on_open` callback with either `'edit'`, `'split'`, `'tabedit'`, or `'vsplit'` as an argument.
8. The `on_open` callback, which is actually `ui.open(ex_command)` (`ex_command` is `'edit'`, `'split'` etc), calls `close()`, which closes the windows and invokes any `on_close` callback.
9. If the UI has an `on_open` callback, it calls it so that it can transform the result. Only the built-in file finder and the watchman finder use this, and they both use it to relativize the result in relation to the `directory`.
10. The thing that actually opens the result is called with `vim.defer_fn()`, to give autocommands a chance to run. The called function is `current_finder.open(result, ex_command)`. Recall from the above that finders like `'fd'` pass in an `options.open` that relativizes the path and uses `sbuffer()` to do a "smart open". Finders like the `'help'` finder define a custom callback. Finders like `'buffer'` and `'jump'` define no `on_open`, so use the default.

## Exec-based finder life-cycle

In most ways, the exec finders follow the same life-cycle described above (and in fact we mention some of them in the descriptions of the steps) so I won't repeat the details here. The main differences are in terms of how they interact with the scanners, but they don't have any implications for how opening works. See the "Memory model" section further down for important differences that exist between the different types in relation to memory ownership.

The other significant difference is that exec finders scan _asynchronously_: rather than blocking the editor until the external command (`fd`, `git-ls-files`, `rg`, `find`, and friends) finishes enumerating what could be hundreds of thousands or millions of files, they fork the command and read its output on a background thread while the UI stays responsive, streaming matches in as candidates arrive. The synchronous scanner (`scanner_new_exec()`) still exists and is used by the benchmark suite, but the exec finder itself uses the asynchronous variant (`scanner_new_exec_async()`). See the "Streaming and concurrency" section for the full picture. (The built-in "file" and watchman finders remain synchronous.)

## Built-in "file" finder life-cycle

Here I'll document only the differences from the other finders:

1. Instead of `commandt.finder(name, directory)`, we call `commandt.file_finder(directory)`.
2. We don't look at `candidates`, `list` (etc) config because there is no specific config required to build this finder. We just `require` the finder directly and forward all the `options` to it.
3. We use `pushd()` to optionally move to another directory, preserving a record of the previous working directory so that we can go back to it.
4. In the call to `ui.show()`, we pass an `on_open(result)` that uses `relativize(directory, result)` to transform the result. `on_close` is `popd`, as mentioned previously.

## Watchman finder life-cycle

Again, only documenting the differences:

1. Like `commandt.file_finder(directory)`, the function we call just takes one param: `commandt.watchman_finder(directory)`.
2. Like `commandt.file_finder()`, this function doesn't do anything special with config; it just forwards `options`.
3. Unlike `commandt.file_finder()`, we don't `pushd`, and we don't pass in an `on_close` that does `popd` either, because watchman doesn't need to change directory to do its job. However, it _does_ require us to pass an `on_open()` that does the `relativize()` trick.

## Summary of finder life-cycles

| Command             | Argument? | Finder function   | Variant | Mode      | Context? | `on_directory`? | `pushd`? | `on_close`/`popd`? |
| ------------------- | --------- | ----------------- | ------- | --------- | -------- | --------------- | -------- | ------------------ |
| `:CommandTBuffer`   | none      | `finder`          | list    | 'file'    | no       | no              | no       | no                 |
| `:CommandTCommand`  | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTFd`       | directory | `finder`          | exec    | 'file'    | no       | yes             | yes      | yes                |
| `:CommandTFind`     | directory | `finder`          | exec    | 'file'    | no       | yes             | yes      | yes                |
| `:CommandTGit`      | directory | `finder`          | exec    | 'file'    | no       | yes             | yes      | yes                |
| `:CommandTHelp`     | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTHistory`  | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTJump`     | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTLine`     | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTRipgrep`  | directory | `finder`          | exec    | 'file'    | no       | yes             | yes      | yes                |
| `:CommandTSearch`   | none      | `finder`          | list    | 'virtual' | no       | no              | no       | no                 |
| `:CommandTTag`      | none      | `finder`          | list    | 'virtual' | yes      | no              | no       | no                 |
| `:CommandTWatchman` | directory | `watchman_finder` | n/a     | 'file'    | no       | no[^direct]     | no       | no                 |
| `:CommandT`         | directory | `file_finder`     | n/a     | 'file'    | no       | no[^direct]     | yes      | yes                |

Legend:

- Argument?: Does the commmand accept an argument?
- Finder function: What is the `commandt` function that serves as entry point?
- Variant: Does the finder use a list scanner (ie. `candidates`) or an exec scanner (ie. `command`)?
- Mode: Is the finder a "file" finder (shows icons) or a "virtual" one?
- Context?: Does the finder make use of the `context` parameter to pass state?
- `on_directory`?: Does the finder use an `on_directory` callback to infer a starting directory if appropriate?
- `pushd`?: Does the finder use `pushd()` before scanning?
- `on_close`/`popd`?: Does the finder use an `on_close` callback and `popd` to go back to the previous directory when closing its UI (and optionally opening a selection)?

[^direct]: These finders don't make use of an `on_directory` callback but instead call `get_directory()` directly.

# Memory model

For maximum performance, Command-T takes great pains to avoid unnecessary copying. This, combined with the fact that memory is passing across Lua's FFI boundary to and from C code, means that there are some subtleties to the question of which code owns any particular piece of memory, and who is responsible for freeing it (either manually from the C code, or automatically via garbage collection initiated on the Lua side).

Ideally this would all be self-documenting and fool-proof, but for now it relies on extremely careful construction.

## Primitives

- **C strings** are wrapped inside a `str_t` struct with three fields (`contents`, `length`, and `capacity`). These strings are (generally) mutable, and functions are provided for truncating and appending; if additional `capacity` is required in order to accommodate the desired `length`, then the backing allocation of the `contents` storage is automatically grown (and potentially moved). When a string is no longer needed, the struct and associated `contents` are released with a call to `str_free()`, which in turn calls `free()`.
  - As a special case, strings can be part of a "slab allocation", which means that the `str_t` points into a large block of memory containing many `str_t` structs, and their `content` pointers also point into a large slab containing string data. These strings are _mostly_ immutable (producing an error if you try to call `str_append()` or `str_append_char()`), although you _can_ call `str_truncate()` on such strings (ie. effectively reducing the `length` value and writing a terminating `NUL` byte at the required location). Calling `str_free()` on a slab-allocated string does nothing; both the structs and their `contents` will remain in memory until the slab allocations themselves get deallocated. Slab-allocated strings are created by calling `str_init()`. As an implementation detail, slab-allocated strings are marked as such by having their `capacity` field set to `-1`. At the time of writing, there are three places in Command-T that create slab-allocated strings:
    1. The built-in `:CommandT` finder (see `find.c`).
    2. In the "exec" scanner (see `scanner.c`).
    3. `watchman_read_string_no_copy()` in the watchman scanner, which is used to read the `"files"` property of the Watchman response (see `watchman.c`).
- **Scanners** manage access to a list of haystacks to be searched. The come in four varieties:
  1. Scanners created by `scanner_new_exec()` (synchronous) or `scanner_new_exec_async()` (asynchronous), which obtain their candidates by running commands like `git-ls-files`, `fd`, `find`, `rg`, and friends. The exec finder (`finders/exec.lua`) uses the asynchronous variant, which produces candidates on a background thread (see "Streaming and concurrency"); the synchronous variant, reached via the "exec" scanner (`scanners/exec.lua`), is retained for the benchmark suite. Both allocate and own the same `candidates` and `buffer` slabs.
  2. Scanners created by `scanner_new()`, called from `find.c`. This scanner does not copy the candidate strings (which are slab-allocated), but it _does_ take ownership of the slabs.
  3. Scanners created by `scanner_new_copy()`, called from `test/matcher.lua`, `benchmarks/matcher.lua` and the "list" scanner (`scanners/list.lua`). As the name indicates, this scanner copies the passed in candidates, creating new `str_t` objects. This scanner is suitable and is used for smaller lists of candidates, like help tags, buffers and so on.
  4. Scanners created by `scanner_new_str()`, called from `watchman.lua`.

## Four patterns for memory ownership

So, at the risk of producing documentation that is very prone to becoming out-of-date as things get refactored, these are the four patterns of memory ownership as manifested in the four different varieties of scanner. In summary:

| Scanner pattern              | Has `candidates`? | `candidates` owner           | Has `buffer`? | `buffer` owner                   | `str_t` are slab-allocated? |
| ---------------------------- | ----------------- | ---------------------------- | ------------- | -------------------------------- | --------------------------- |
| `scanner_new_exec[_async]()` | Yes               | `scanner_t` (created)        | Yes           | `scanner_t` (created)            | Yes                         |
| `scanner_new()`              | Yes               | `scanner_t` (assigned)       | Yes           | `scanner_t` (assigned)           | Yes                         |
| `scanner_new_copy()`         | Yes               | `scanner_t` (created)        | No            | n/a                              | No                          |
| `scanner_new_str()`          | Yes               | `watchman_query_t` (`files`) | Yes           | `wathcman_reponse_t` (`payload`) | Yes                         |

Details follow.

### `scanner_new_exec()` and `scanner_new_exec_async()`

This is the most common form of scanning in Command-T, used by anything that wraps an external command (eg. `:CommandTGit`, wrapping `git-ls-files`, `:CommandTRipgrep`, wrapping `rg`, and so on). Two variants share an identical memory-ownership model but differ in when, and on which thread, candidates are produced: `scanner_new_exec()` reads the command to completion synchronously (retained for the benchmark suite, reached via `scanners/exec.lua`), while `scanner_new_exec_async()` returns immediately and produces on a background thread. The exec finder uses the asynchronous variant; see "Streaming and concurrency" for the threading details.

- The main controller (defined in `init.lua`) calls `finders.exec()` (defined in `finders/exec.lua`) to obtain a `finder`:
  - `finders.exec()` calls `lib.scanner_new_exec_async()`, which calls `commandt_scanner_new_exec_async()` via FFI:
    - That function creates a `candidates` slab and a `buffer` slab with `xmap()`. The former stores zero-copy `str_t` records (created with `str_init()`), while the latter holds the actual command output, into which the `str_t` records index via their `contents` pointers. It then forks the command and spawns the producer thread that fills those slabs. (The synchronous `scanner_new_exec()` is identical except that it fills the slabs inline before returning.)
  - `lib.scanner_new_exec_async()` uses `ffi.gc()` to mark the returned `scanner` object such that when it is garbage-collected, the `commandt_scanner_free()` function will be called:
    - `commandt_scanner_free()` first calls `commandt_scanner_stop()` to join the producer thread and reap the child (a no-op for the synchronous scanner and the non-exec scanner kinds), then uses `xmunmap()` to release the `candidates` and `buffer` slabs, and `free()` to deallocate the `scanner_t` struct itself.
    - Note that it also contains a `for` loop that _would_ call `free` on all of the `str_t` records in `candidates`, but the `for` loop is a no-op because all of those strings are slab-allocated and there is an `if` that checks this condition. (It does this `if` check rather than calling `str_free()` in order to save an unnecessary function call; `str_free()` on a slab-allocated `str_t` is a no-op.)
  - `finders.exec()` passes the `scanner` into `lib.matcher_new()`, and returns a `finder` object that exposes a `run()` function (calling `lib.matcher_run()`); the `finder` object has a reference to the `scanner`, which keeps it alive until the `finder` itself falls out of scope.
- The returned `finder` is passed into `ui.show()`, which stores a reference in the module-local `current_finder` variable, keeping the `finder` alive until the next time `ui.show()` is called and a different `finder` is passed in.

The overall ownership chain, then, is: the `finder` owns the `scanner`, the `scanner` owns its `candidates` slab and `buffer` slab, and the `str_t` structs in the `candidates` slab do not own their individual `contents` because those are all slab-allocated. The only wrinkle beyond the synchronous case is that `commandt_scanner_free()` joins the producer thread (via `commandt_scanner_stop()`) before releasing the slabs it was writing into.

### `scanner_new()` as used by the built-in `:CommandT` finder

- The main controller (defined in `init.lua`) calls `finders.file()` to obtain a `finder`:
  - `finders.file()` (defined in `finders/file.lua`) calls `scanner()` (defined in `scanners/file.lua`) to obtain a `scanner` instance:
    - `scanner()` calls `lib.file_scanner()` to obtain and return a `scanner`:
      - `lib.file_scanner()` (defined in `private/lib.lua`) calls `commandt_file_scanner()` via FFI:
        - `commandt_file_scanner()` (defined in `find.c`), calls `commandt_find()` (also in `find.c`).
        - `commandt_find()` allocates two slabs with `xmap()`: the `files` slab for holding `str_t` records, and the `buffer` slab for holding string `contents`.
        - As it walks the directory tree, it copies file paths into the `buffer` slab (with `memcpy()`), and creates `str_t` records in the `files` slab, using `str_init()` so as to avoid a redundant copy operation.
        - Once traversal is finished, `commandt_file_scanner()` passes the two slabs into `scanner_new()`, which takes ownership of them rather than copying them.
        - `commandt_file_scanner()` then frees (with `free()`) the left-over book-keeping data structures used by `commandt_find()`, taking care to ensure that it does _not_ free the slabs.
      - `lib.file_scanner()` uses `ffi.gc()` to mark the returned `scanner` such that when it is garbage-collected, the `commandt_scanner_free()` function will be called:
        - `commandt_scanner_free()` will free its `candidates` slab (containing `str_t` objects) (with `xmunmap()`).
        - It will also free (with `xmunmap()`) its `buffer` (string storage) and the `scanner_t` struct itself.
        - Note that it also contains a `for` loop that _would_ call `free` on all of the `str_t` records in `candidates`, but the `for` loop is a no-op because all of those strings are slab-allocated and there is an `if` that checks this condition. (It does this `if` check rather than calling `str_free()` in order to save an unnecessary function call; `str_free()` on a slab-allocated `str_t` is a no-op.)
  - `finders.file()` passes the `scanner` into `lib.matcher_new()`, and returns a `finder` object that exposes a `run()` function (calling `lib.matcher_run()`); the `finder` object has a reference to the `scanner`, which keeps it alive until the `finder` itself falls out of scope.
- The returned `finder` is passed into `ui.show()`, which stores a reference in the module-local `current_finder` variable, keeping the `finder` alive until the next time `ui.show()` is called and a different `finder` is passed in.

The overall ownership chain, then, is: the `finder` owns the `scanner`, the `scanner` assumes ownership of the `candidates` and `buffer` slabs passed into it, and the `str_t` structs in `candidates` do not own their individual `contents` because those are all slab-allocated.

### `scanner_new_copy()` as used to create "list" scanners

- The main controller (defined in `init.lua`) calls `finders.list()` to obtain a `finder`:
  - `finders.list()` (defined in `finders/list.lua`) calls `scanner()` (defined in `scanners/list.lua`) to obtain a `scanner` instance:
    - `scanner()` calls `lib.scanner_new_copy()` to obtain and return a `scanner`:
      - `lib.scanner_new_copy()` (defined in `private/lib.lua`) calls `commandt_scanner_new_copy()` via FFI:
        - `commandt_scanner_new_copy()` uses `xmap()` to create `candidates` storage (for `str_t` structs).
        - It uses `str_init_copy()` to create `str_t` objects in the slab which themselves reference storage obtained via `xmalloc()` and populated with `memcpy()`. This is why, as mentioned above, "list" scanners are only suitable for smaller sets of candidates.
      - `lib.scanner_new_copy()` uses `ffi.gc()` to mark the returned `scanner` such that when it is garbage-collected, the `commandt_scanner_free()` function will be called:
        - `commandt_scanner_free()` will free its `candidates` (with `xmunmap()`) after calling `free()` on the `contents` storage of each `str_t` in the `candidates` slab.
        - It will not free its `buffer` because it does not use one.
        - It will free the `scanner_t` struct itself.
  - `finders.list()` passes the `scanner` into `lib.matcher_new()`, and returns a `finder` object that exposes a `run()` function (calling `lib.matcher_run()`); the `finder` object has a reference to the `scanner`, which keeps it alive until the `finder` itself falls out of scope.
- The returned `finder` is passed into `ui.show()`, which stores a reference in the module-local `current_finder` variable, keeping the `finder` alive until the next time `ui.show()` is called and a different `finder` is passed in.

The overall ownership chain, then, is: the `finder` owns the `scanner`, the `scanner` owns its `candidates` slab (but has no `buffer` slab), and the `str_t` structs in the `candidates` slab own individual `contents` allocations.

### `scanner_new_str()` as used by `:CommandTWatchman`

- The main controller (defined in `init.lua`) calls `finders.watchman()` to obtain a `finder`:
  - `finders.watchman()` (defined in `finders/watchman.lua`) calls `scanner()` (defined in `scanners/watchman.lua`) to obtain a `scanner` instance:
    - `scanner()` calls `lib.watchman_watch_project()`
    - `scanner()` then calls `lib.watchman_query()`
      - `lib.watchman_query()` calls `commandt_watchman_query()` via FF:
        `commandt_watchman_query()`
      - `lib.watchman_query()` uses `ffi.gc()` to mark the returned `result.raw` object such that when it is garbage-collected, `commandt_watchman_query_free()` function will be called.
        - `commandt_watchman_query_free()` uses `xmunmap()` to free the `files` slab.
        - It calls `watchman_response_free()` to free the `response`:
          - `watchman_response_free()` calls `free()` on the `payload` and on the `watchman_response_t` struct itself.
        - It also calls `free()` on the `error` and on the `result` struct itself.
      - In the happy path, `commandt_watchman_query()` uses `watchman_send()` to send the query:
        - `watchman_send()` creates a `watchman_response_t` with `payload` buffer of size 4096, calling `xrealloc()` if necessary to grow the buffer once it has sniffed the initial part of the response to see how much storage is needed overall.
      - Parsing the response, `commandt_watchman_query()` uses `xmap()` to prepare an appropriately sized `files` slab.
      - It then creates strings using `watchman_read_string_no_copy()` directly into the `files` slab:
        `watchman_read_string_no_copy()` uses `str_init()` to create zero-copy `str_t` structs in the `files` slab that point at addresses within the `payload` buffer inside the `watchman_reponse_t`.
    - `scanner()` it passes a pointer (`result.raw.files`) into `lib.scanner_new_str()`:
      - `lib.scanner_new_str()` calls `scanner_new_str()` via FF:
        - `scanner_new_str()` marks both `candidates` and `buffer` as unowned (and in fact, `buffer` is `NUL`) by using the special value of `-1` for `candidates_size` and `buffer_size`. This is similar to how `str_t` uses a `capacity` of `-1` to label something as belonging to a slab allocation.
      - `lib.scanner_new_str()` uses `ffi.gc()` to mark the returned `scanner` such that when it is garbage-collected, the `commandt_scanner_free()` function will be called.
      - `commandt_scanner_free()` will _not_ free the `candidates` and `buffer` slabs because the `scanner` does not own those; it only calls `free` on the `scanner_t` struct itself.
    - `scanner()` stores a reference to the `result` object in a weak table, using the `scanner` as a key. The `result` object has a reference to the `result.raw` property, preventing it from being prematurely garbage collected.
  - `finders.watchman()` passes the `scanner` into `lib.matcher_new()`, and returns a `finder` object that exposes a `run()` function (calling `lib.matcher_run()`); the `finder` object has a reference to the `scanner`, which keeps it alive until the `finder` itself falls out of scope.
- The returned `finder` is passed into `ui.show()`, which stores a reference in the module-local `current_finder` variable, keeping the `finder` alive until the next time `ui.show()` is called and a different `finder` is passed in.

This last one has the most complicated ownership chain: the `finder` owns the `scanner`, the `scanner` references the `result` only via the weak table, and the `result` references the `raw` return value from `watchman_query()` (ie. the `watchman_query_t`) which owns the `files` slab, which in turn contains pointers to string `contents` in the `watchman_response_t`. When the `scanner` is garbage collected, the last reference to `result` goes away, which in turn means the last reference to `result.raw` goes away, which causes `commandt_watchman_query_free()` to run, freeing the `files` slab, and calling `watchman_response_free()` which frees the `payload`. This could probably be improved.

# Streaming and concurrency

Exec-based finders (`:CommandTFd`, `:CommandTFind`, `:CommandTGit`, `:CommandTRipgrep`, and any user-defined `command` finder) scan asynchronously, so that opening the finder is instant even in a repository with hundreds of thousands or millions of files, where the external command can take seconds to enumerate them. Instead of running the command to completion and only then showing the UI, Command-T shows the UI immediately and streams matches in as the command produces output.

## The producer thread

`commandt_scanner_new_exec_async()` (in `scanner.c`, wrapped by `lib/scanner_new_exec_async.lua`) allocates the `candidates` and `buffer` slabs exactly as the synchronous scanner does, then forks the command and returns immediately, spawning a background "producer" thread (`exec_producer()`) that owns the read loop. The producer blocking-reads the child's stdout into the `buffer` slab and tokenizes it into zero-copy `str_t` records in the `candidates` slab (via the shared `scanner_tokenize()` helper), publishing its progress by advancing the candidate `count`.

The slabs are large, sparse `mmap()` reservations that are never resized or moved, so production is purely append-only: the producer writes `candidates[count]` and then advances `count`. That single field, `scanner->count`, is the entire synchronization surface between the producer and the consumer. The producer publishes it with a release store (`__atomic_store_n(..., __ATOMIC_RELEASE)`) after fully writing a batch of `str_t` records; the consumer (the matcher, on the main thread) reads it with an acquire load. Because the slabs never move and every entry below `count` is immutable once published, no locks are required, and the release/acquire pair guarantees that a consumer which observes a given `count` also observes the fully-initialized candidates below it.

The tokenizer never writes past the `candidates` slab even when the user's `max_files` is 0 (unlimited): the slab's capacity (`MAX_FILES`) is an unconditional hard cap.

## The consumer (matcher)

The matcher runs on the main thread. `matcher_new()` sizes its `haystacks` slab to the scanner's `capacity` (for an async exec scanner, `MAX_FILES`) with `xmap()`, so, like the other slabs, it never has to move as candidates stream in; only the entries actually touched are faulted into physical memory. Each call to `commandt_matcher_run()` takes an acquire-loaded snapshot of `count`, lazily initializes any `haystack_t` entries that have appeared since the previous run, and has all of its worker threads iterate against that fixed snapshot (rather than re-reading the live `count`), so a single run always works against a consistent candidate set. The existing incremental-narrowing optimization composes with streaming for free: freshly-initialized haystacks carry `UNSET_SCORE` rather than `0.0f`, so the "didn't match last time, skip it" fast path never wrongly skips a newly-arrived candidate. The `result_t` returned by each run is handed to the Lua garbage collector via `ffi.gc()` (in `lib/matcher_run.lua`), so callers never have to free it explicitly.

## Lifecycle and cancellation

The scanner exposes two additional entry points for the async case:

- `commandt_scanner_done()`: an acquire-load of a `done` flag the producer sets when it finishes (or is stopped). Always true for non-async scanners.
- `commandt_scanner_stop()`: cancels and cleans up. It kills the child's whole process group, joins the producer thread, reaps the child, and closes the pipe. It is idempotent and a no-op for non-async scanners. `commandt_scanner_free()` calls it, so a scanner that is merely garbage-collected without an explicit stop still cleans up.

Two subtleties make cancellation safe:

- **Process-group termination.** The command runs as `/bin/sh -c '<command> 2> /dev/null'`, and because of the redirection (and pipelines like `git ls-files | ...`) the shell _forks_ the real tool rather than replacing itself with it. Killing only the shell would orphan the tool, which keeps the pipe's write end open and leaves the producer blocked in `read()`. So the child is placed in its own process group (`setpgid()`), and `scanner_stop()` signals the whole group (`kill(-pid, ...)`), which terminates the tool too and lets the producer's `read()` return EOF promptly. Without this, closing the finder mid-scan would block the main thread on the join.
- **Deferred reaping.** The producer never reaps the child; `scanner_stop()` does, but only _after_ joining the producer thread. This keeps the child's PID valid (as an unreaped zombie) for the entire window in which `scanner_stop()` might signal it, so the signal can never race child exit and land on an unrelated, PID-recycled process.

## The UI loop

The UI (`ui.lua`) drives the stream. When a streaming finder is shown, `UI:_start_scanning()` starts a repeating `vim.uv` timer (~50ms). Each tick, marshaled from the timer's "fast" context to a normal context via `vim.schedule()`, re-runs the current query against whatever has been produced so far and repaints the match listing, until `finder.done()` reports completion, at which point the timer is stopped and the producer joined. Keystrokes and timer ticks share a single `UI:_refresh()` path.

A few behaviors fall out of this:

- **Selection is preserved across streaming refreshes.** A keystroke resets the selection to the best match; a streaming refresh keeps the user where they were (clamped), so results filling in underneath don't yank the cursor around.
- **The fallback decision is deferred until scanning finishes.** A streaming finder legitimately reports zero candidates while it is still starting up, so the fallback to the built-in file finder is only considered once `done` is true (otherwise every scan would briefly flip to the fallback finder).
- **Progress is shown while scanning.** While a scan is streaming, Command-T shows a spinner and a right-aligned "matching / scanned" count (eg. `⠧ 42 / 706,248`). The count only appears once the first candidate has arrived, so an empty scan (or the synchronous fallback walk) never shows a frozen `0 / 0`.

## What is still synchronous

The synchronous `scanner_new_exec()` is retained and exercised by the scanner benchmark. The built-in "file" finder (`find.c`, `commandt_file_scanner()`) still walks the filesystem synchronously on the main thread, which is also why the exec finders' fallback to it can briefly block on a cold, large tree; making the file finder stream as well is a natural future extension[^future]. The watchman finder receives its candidates as a single in-memory payload, so it has nothing to stream.

[^future]: One reason I'm not pursuing this now is that the directory traversal would need to pass `FTS_NOCHDIR` (to stop it from changing the process-global working directory along the way), which in turn would make fallback scanning even slower (it is already quite slow compared to a parallel traversal like the one done by `fd`).
