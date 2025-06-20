# Memory model

For maximum performance, Command-T takes great pains to avoid unnecessary copying. This, combined with the fact that memory is passing across Lua's FFI boundary to and from C code, means that there are some subtleties to the question of which code owns any particular piece of memory, and who is responsible for freeing it (either manually from the C code, or automatically via garbage collection initiated on the Lua side).

Ideally this would all be self-documenting and fool-proof, but for now it relies on extremely careful construction.

## Primitives

- **C strings** are wrapped inside a `str_t` struct with three fields (`contents`, `length`, and `capacity`). These strings are (generally) mutable, and functions are provided for truncating and appending; if additional `capacity` is required in order to accommodate the desired `length`, then the backing allocation of the `contents` storage is automatically grown (and potentially moved). When a string is no longer needed, the struct and associated `contents` are released with a call to `str_free()`, which in turn calls `free()`.
  - As a special case, strings can be part of a "slab allocation", which means that the `str_t` points into a large block of memory containing many `str_t` structs, and their `content` pointers also point into a large slab containing string data. These strings are _mostly_ immutable (producing an error if you try to call `str_append()` or `str_append_char()`), although you _can_ call `str_truncate()` on such strings (ie. effectively reducing the `length` value and writing a terminating `NUL` byte at the required location). Calling `str_free()` on a slab-allocated string does nothing; both the structs and their `contents` will remain in memory until the slab allocations themselves get deallocated. Slab-allocated strings are created by calling `str_init()`. As an implementation detail, slab-allocated strings are marked as such by having their `capacity` field set to `-1`. At the time of writing, there are three places in Command-T that create slab-allocated strings:
    1. The built-in `:CommandT` finder (see `find.c`).
    2. In the "command" scanner (see `scanner.c`).
    3. `watchman_read_string_no_copy()` in the watchman scanner, which is used to read the `"files"` property of the Watchman response (see `watchman.c`).
- **Scanners** manage access to a list of haystacks to be searched. The come in four varieties:
  1. Scanners created by `scanner_new_command()`, called from the "command" scanner (`scanners/command.lua`). As the name suggests, this scanner obtains its candidates by running commands like `git-ls-files`, `fd`, `find`, `rg`, and friends.
  2. Scanners created by `scanner_new()`, called from `find.c`. This scanner does not copy the candidate strings (which are slab-allocated), but it _does_ take ownership of the slabs.
  3. Scanners created by `scanner_new_copy()`, called from `test/matcher.lua`, `benchmarks/matcher.lua` and the "list" scanner (`scanners/list.lua`). As the name indicates, this scanner copies the passed in candidates, creating new `str_t` objects. This scanner is suitable and is used for smaller lists of candidates, like help tags, buffers and so on.
  4. Scanners created by `scanner_new_str()`, called from `watchman.lua`.

## Four patterns for memory ownership

So, at the risk of producing documentation that is very prone to becoming out-of-date as things get refactored, these are the four patterns of memory ownership as manifested in the four different varieties of scanner. In summary:

| Scanner pattern         | Has `candidates`? | `candidates` owner           | Has `buffer`? | `buffer` owner                   | `str_t` are slab-allocated? |
| ----------------------- | ----------------- | ---------------------------- | ------------- | -------------------------------- | --------------------------- |
| `scanner_new_command()` | Yes               | `scanner_t` (created)        | Yes           | `scanner_t` (created)            | Yes                         |
| `scanner_new()`         | Yes               | `scanner_t` (assigned)       | Yes           | `scanner_t` (assigned)           | Yes                         |
| `scanner_new_copy()`    | Yes               | `scanner_t` (created)        | No            | n/a                              | No                          |
| `scanner_new_str()`     | Yes               | `watchman_query_t` (`files`) | Yes           | `wathcman_reponse_t` (`payload`) | Yes                         |

Details follow.

### `scanner_new_command()`

This is the most common form of scanning in Command-T, used by anything that wraps an external command (eg. `:CommandTGit`, wrapping `git-ls-files`, `:CommandTRipgrep`, wrapping `rg`, and so on).

- The main controller (defined in `init.lua`) calls `finders.command()` to obtain a `finder`:
  - `finders.command()` (defined in `finders/command.lua`) calls `scanner()` (defined in `scanners/command.lua`) to obtain a `scanner` instance:
  - `scanner()` calls `lib.scanner_new_command()` to obtain and return a `scanner`:
    - `lib.scanner_new_command()` calls the `scanner_new_command()` via FFI:
      - `scanner_new_command()` creates a `candidates` slab and a `buffer` slab with `xmap()`. The former is used to store zero-copy `str_t` records (created with `str_init()`), while the latter holds the actual command output, into which the `str_t` records index via their `contents` pointers.
    - `lib.scanner_new_command()` uses `ffi.gc()` to mark the returned `scanner` object such that when it is garbage-collected, the `commandt_scanner_free()` function will be called:
      - `commandt_scanner_free()` uses `xmunmap()` to release the `candidates` and `buffer` slabs, and `free()` to deallocate the `scanner_t` struct itself.
      - Note that it also contains a `for` loop that _would_ call `free` on all of the `str_t` records in `candidates`, but the `for` loop is a no-op because all of those strings are slab-allocated and there is an `if` that checks this condition. (It does this `if` check rather than calling `str_free()` in order to save an unnecessary function call; `str_free()` on a slab-allocated `str_t` is a no-op.)
  - `finders.command()` passes the `scanner` into `lib.matcher_new()`, and returns a `finder` object that exposes a `run()` function (calling `lib.matcher_run()`); the `finder` object has a reference to the `scanner`, which keeps it alive until the `finder` itself falls out of scope.
- The returned `finder` is passed into `ui.show()`, which stores a reference in the module-local `current_finder` variable, keeping the `finder` alive until the next time `ui.show()` is called and a different `finder` is passed in.

The overall ownership chain, then, is: the `finder` owns the `scanner`, the `scanner` owns its `candidates` slab and `buffer` slab, and the `str_t` structs in the `candidates` slab do not own their individual `contents` because those are all slab-allocated.

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
