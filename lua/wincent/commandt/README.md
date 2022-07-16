## Memory model

We want to avoid copying large numbers of strings back and forth.

Similar to existing Command-T model, have a "Finder" instance that maintains a reference to a "Scanner" instance. The scanner can hold a copy of the candidate strings to be searched, and the C code can keep a copy of those strings (ideally, not even a copy). If we must use a copy, then we can use `ffi.gc()` to effectively call our destructor when the scanner goes out of scope.

For returning results back, we only ever have a small number (say, 10), and can easily copy those strings back.

## Benchmarks

On Apple Silicon, where the `luajit` package is not currently available in Homebrew, but `neovim` itself requires `luajit-openresty` package, you can add a working `luajit` executable to your `$PATH` with:

```
export PATH="/opt/homebrew/opt/luajit-openresty/bin:$PATH"
```

After which, `bin/benchmarks/matcher.lua` will work.

## TODO

- Keep adding tests.
- Add scanner benchmarks.
