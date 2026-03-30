# Contributing

Patches are welcome via the usual mechanisms (pull requests, email, posting to the project issue tracker etc).

For more details, see the "command-t-development" section in [the documentation](https://github.com/wincent/command-t/blob/main/doc/command-t.txt).

# Releasing

1. Update "command-t-history" section in `doc/command-t.txt`.
2. Edit metadata in `lua/wincent/commandt/version.lua` to reflect new `$VERSION` (remove `prelease = 'main'`).
3. Commit using `git commit -p -m "chore: prepare for $VERSION release"`.
4. Create tag with `git tag -s $VERSION -m "$VERSION release"`.
5. Fast-forward the `release` branch to match the tag.
6. Check release readiness with `make check`.
7. Push with `git push --follow-tags`.
8. Update [release notes on GitHub](https://github.com/wincent/command-t/releases).
9. Start a new entry under "command-t-history" in `doc/command-t.txt` for subsequent development.
10. Edit metadata in `lua/wincent/commandt/version.lua` to show `prelease = 'main'` and `version = 'x.y.z-main`.

# Reproducing bugs

Sometimes [user bug reports](https://github.com/wincent/command-t/issues) depend on characteristics of their local setup. Reproducing this may require copying configuration and installing dependencies, something I'd rather not do to my own development system. So, here are some notes about setting up a disposable [Tart](https://tart.run/) VM on macOS (Apple Silicon) to try things out in a controlled environment.

## Installing Tart

```bash
brew install cirruslabs/cli/tart
```

## Creating a VM

```bash
tart clone ghcr.io/cirruslabs/ubuntu:latest command-t-sandbox
tart run --no-graphics command-t-sandbox
```

In a separate terminal, SSH in (default credentials are `admin`/`admin`):

```bash
ssh admin@$(tart ip command-t-sandbox)
```

## Setting up Neovim on the VM

The current Ubuntu image (at the time of writing, that's 24.04) ships Neovim 0.9.5 via apt, which is relatively ancient:

```bash
sudo apt-get update
sudo apt-get install -y neovim build-essential
```

If a newer version is needed, build from source:

```bash
sudo apt-get install -y ninja-build gettext cmake curl build-essential
git clone --depth=1 https://github.com/neovim/neovim
cd neovim
make CMAKE_BUILD_TYPE=RelWithDebInfo
sudo make install
```

## Installing Command-T and other dependencies manually

```bash
BUNDLE=$HOME/.config/nvim/pack/bundle/start
mkdir -p $BUNDLE
git clone --depth 1 https://github.com/wincent/command-t $BUNDLE/command-t
echo "require('wincent.commandt').setup()" > ~/.config/nvim/init.lua
(cd $BUNDLE/command-t && make)

# Also install any other plug-ins that might be needed to reproduce a problem; eg:

git clone --depth 1 https://github.com/jiangmiao/auto-pairs $BUNDLE/auto-pairs
```

## Installing Command-T using lazy.nvim

For reproducing reports that involve a plugin manager:

```bash
# Note we need `--filter=blob:none` here instead of `--depth=1` because lazy.nvim
# needs the metadata about the Git history for its lockfile implementation.
git clone --filter=blob:none --branch=stable \
  https://github.com/folke/lazy.nvim ~/.local/share/nvim/lazy/lazy.nvim
```

Then, in `~/.config/nvim/init.lua`:

```lua
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')

require('lazy').setup({
  {
    'wincent/command-t',
    build = 'make',
    config = function()
      require('wincent.commandt').setup()
    end,
  },
})
```

## Cleaning up after testing is done

```bash
exit                            # Leave the SSH session.
tart stop command-t-sandbox     # Stop the VM.
tart delete command-t-sandbox   # Delete the VM image.
```

# Profiling

In order to get intelligible stack traces, compile with debug symbols with:

```
make PROFILE=1
```

## On macOS

I didn't have any success the last time I tried `xctrace`, but including the notes here for reference anyway:

```
xctrace record --launch bin/benchmarks/matcher.lua --template "CPU Profiler" # Instruments.app hangs while opening this.
xctrace record --launch bin/benchmarks/matcher.lua --template "Time Profiler" # Instruments.app hangs while opening this.
xctrace record --launch bin/benchmarks/matcher.lua --template "Activity Monitor" # Produces not very useful system-wide stats.
xctrace record --launch bin/benchmarks/matcher.lua --template "Allocations" # Completes with an error and produces no useful info.
```

In theory, should be able to run the following, but it hangs:

```
xctrace symbolicate --input some.trace --dsym lua/wincent/commandt/lib/commandt.so.dSYM
```

I also attempted using the `/usr/bin/sample` tool, which produces results, albeit not particularly easy ones to parse:

```
(sleep 1 && luajit bin/benchmarks/matcher.lua) &
sample -wait luajit -mayDie
```

`dtrace`, however, produced a useful result, albeit with some hoop-jumping required:

```
sudo -v
luajit bin/benchmarks/matcher.lua & ; DTRACE_PID=$! ; sudo vmmap $DTRACE_PID | grep commandt.so ; sudo dtrace -x ustackframes=100 -p $DTRACE_PID -n \
  'profile-100 /pid == '$DTRACE_PID'/ { @[ustack()] = count(); }' -o dtrace.stacks
```

ie. refresh sudo credentials, kick off `luajit`, grab the base address of the `commandt`.so library so that we can symbolicate later on, run `dtrace` for 60s, sample 100 times per second (ie. every 10ms), grab user stack (not kernel frames), then exit.

I tried a few tricks[^tricks] to get `dtrace` to symbolicate for us automatically but eventually had to do it manually with `atos`. Grab the base address of the `__TEXT` segment (printed by `vmmap`); in this example, `0x104ac0000`:

```
__TEXT                      104ac0000-104ac8000    [   32K    32K     0K     0K] r-x/rwx SM=COW          /Users/USER/*/commandt.so
__DATA_CONST                104ac8000-104acc000    [   16K    16K    16K     0K] r--/rwx SM=COW          /Users/USER/*/commandt.so
__LINKEDIT                  104acc000-104ad0000    [   16K    16K     0K     0K] r--/rwx SM=COW          /Users/USER/*/commandt.so
```

Then run this hacky script:

```
cat dtrace.stacks | bin/symbolicate-dtrace 0x104ac0000 > dtrace.symbolicated
```

Which produces output that can then be visualized with:

```
git clone https://github.com/brendangregg/FlameGraph
cd FlameGraph
./stackcollapse.pl dtrace.symbolicated > dtrace.collapsed
./flamegraph.pl dtrace.collapsed > dtrace.svg
```

[^tricks]: Tricks which didn't work included running from inside `lua/wincent/commandt/lib` (where the dSYM bundle is), and moving the dSYM bundle up to the root and running from there.

    The probable reason why automatic symbol discovery doesn't work is the UUID mismatch between the library and the process that `dtrace` is executing:

    ```
    dwarfdump --uuid lua/wincent/commandt/lib/commandt.so       # This matches...
    dwarfdump --uuid lua/wincent/commandt/lib/commandt.so.dSYM  # ... with this;
    dwarfdump --uuid /opt/homebrew/bin/luajit                   # but not with this.
    ```

I also had success straightforwardly with [Samply](https://github.com/mstange/samply):

```
cargo install --locked samply
TIMES=1 ~/.cargo/bin/samply record luajit bin/benchmarks/matcher.lua
```

**Note:** Using `TIMES=1` because otherwise the generated `profile.json` is too big and crashes Chrome (but not Safari).

### Using PGO (Profile-Guided Optimizations)

Make a build that collects profiling data:

```
make CFLAGS=-fprofile-generate
```

Run the program to generate the profiling data:

```
TIMES=1 bin/benchmarks/matcher.lua
```

Prepare the data:

```
xcrun llvm-profdata merge -output=lua/wincent/commandt/lib/default.profdata *.profraw
```

Make a build using the profiling data:

```
make CFLAGS=-fprofile-use
```
