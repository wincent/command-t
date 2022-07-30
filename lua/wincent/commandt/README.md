## Memory model

We want to avoid copying large numbers of strings back and forth.

Similar to existing Command-T model, have a "Finder" instance that maintains a reference to a "Scanner" instance. The scanner can hold a copy of the candidate strings to be searched, and the C code can keep a copy of those strings (ideally, not even a copy). If we must use a copy, then we can use `ffi.gc()` to effectively call our destructor when the scanner goes out of scope.

For returning results back, we only ever have a small number (say, 10), and can easily copy those strings back.

## Benchmarks

On Apple Silicon, where the `luajit` package is not currently available in Homebrew, but `neovim` itself requires `luajit-openresty` package, you can add a working `luajit` executable to your `$PATH` with:

```
export PATH="/opt/homebrew/opt/luajit-openresty/bin:$PATH"
```

After which, `bin/benchmarks/matcher.lua` (and `bin/benchmarks/scanner.lua`) will work.

### Debugging

```
gdb luajit
(gdb) r -- ./bin/benchmarks/scanner.lua
(gdb) bt
```

### Matcher benchmarks

#### Thread counts

We have a heuristic for guessing the "optimal" thread count based on the number of available cores reported by the operating system. The heuristic doesn't have to be perfect, it just has to be good enough, because users can always override it by explicitly providing a `threads` setting. In short the heuristic is:

- For systems with up to 8 CPU cores, use 1 thread per core.
- For all other systems, beyond the 8th CPU core, add 1 more thread for every 4 additional cores.

Intuitively, the explanation for the heuristic is that, while the matching work is computationally bounded and mostly parallelizable, we still see diminishing returns as we scale up to more and more threads due to the overhead of setting up and tearing down those threads, as well as the cost of scheduling and coordinating all of the memory accesses performed by those threads. The following sections provide support for this decision in the form of benchmark numbers captured on different machine types in July 2022. In all of the following, `n` refers to the number of threads, and the `total` refers to the total time for _all_ of the benchmark inputs (eg. the times for the "pathological", "command-t", "chromium (subset)", "chromium (whole)", _and_ "big (400k)" inputs, summed together).

These particular numbers were captured during an extreme heat-wave, which does mean that thermal throttling effects are more likely to have had an effect (both in terms of reducing performance overall, but also increasing variability and sensitivity to things like gaps between benchmark runs), but also that the workload in some sense is useful as a truly "worst case" scenario.

##### Mid-2015 15" MacBook Pro (Intel)

[According to EveryMac.com](https://everymac.com/systems/apple/macbook_pro/specs/macbook-pro-core-i7-2.8-15-dual-graphics-mid-2015-retina-display-specs.html):

> This model is powered by a 22 nm, 64-bit "Fourth Generation" Intel Mobile Core i7 "Haswell/Crystalwell" (I7-4980HQ) processor which includes four independent processor "cores" on a single silicon chip. Each core has a dedicated 256k level 2 cache, shares 6 MB of level 3 cache, and has an integrated memory controller (dual channel).
>
> This system also supports "Turbo Boost 2.0" -- which "automatically increases the speed of the active cores" to improve performance when needed (up to 4.0 GHz for this model) -- and "Hyper Threading" -- which allows the system to recognize eight total "cores" or "threads" (four real and four virtual).

Despite the "Hyper Threading" functionality, this system reports itself as having 4 cores. I ran tests from `n = 1` through `n = 4`, and I repeated the `n = 4` test to verify it as the lowest/fastest time:

```
               best    avg      sd      +/-      p      (best)    (avg)      (sd)     +/-      p
n = 1: total 6.45749 6.74390  0.75483 [+0.0%]         (6.46032) (6.74947) (0.77442) [+0.0%]
n = 2: total 7.12063 8.41947  3.40996 [+19.9%] 0.0005 (4.10141) (4.88935) (2.06998) [-38.0%] 0.0005
n = 3: total 7.89583 9.87015  3.03138 [+14.7%] 0.0005 (3.33891) (4.30639) (1.45984) [-13.5%] 0.0005
n = 4: total 8.22336 10.52213 4.61827 [+6.2%]  0.0005 (2.93137) (3.84587) (1.74368) [-12.0%] 0.0005

n = 4: total 9.02153 11.54666 2.78264 [+8.9%]  0.0005 (3.17405) (4.23569) (1.26388) [+9.2%]  0.0005
```

As expected, we see wall-clock time (the items in parentheses) going down as we add more threads, just as we see CPU time going up as we demand more CPU resources. We also see a statistically significant increase in time on the second `n = 4` run, which seems reasonable to attribute to thermal throttling. In any case, even the slower of the two `n = 4` runs is faster than the `n = 3` run, so it is clear that for this machine, setting `n` equal to the number of cores is best.

##### 2020 13" MacBook Pro (M1)

This is an Apple Silicon with 8 cores (4 "performance" cores, 4 "efficiency" cores) as [described by EveryMac.com](https://everymac.com/systems/apple/macbook_pro/specs/macbook-pro-m1-8-core-13-2020-specs.html):

> This model is powered by a 5 nm, 64-bit Apple M1 processor (SoC) with eight cores (4 performance cores, 4 efficiency cores). Third-party software reports that it has a clockspeed of 3.2 GHz. It also has an 8-core GPU and a 16-core Neural Engine.

This system reports as having 8 cores. I ran tests for `n = 1` through `n = 8`, and repeated the runs for the low points at `n = 4` and `n = 8` to confirm:

```
               best    avg     sd       +/-      p      (best)    (avg)      (sd)     +/-      p
n = 1: total 4.37047 4.39323 0.12655  [+0.0%]         (4.37053) (4.39353) (0.12656) [+0.0%]
n = 2: total 4.67425 4.70087 0.12393  [+6.5%]  0.0005 (2.64760) (2.67127) (0.12172) [-64.5%] 0.0005
n = 3: total 5.02824 5.06596 0.12174  [+7.2%]  0.0005 (2.10723) (2.13617) (0.14508) [-25.0%] 0.0005
n = 4: total 5.17580 5.22795 0.19282  [+3.1%]  0.0005 (1.78926) (1.81706) (0.13448) [-17.6%] 0.0005
n = 5: total 5.85546 5.90252 0.18319  [+11.4%] 0.0005 (2.02490) (2.05706) (0.11771) [+11.7%] 0.0005
n = 6: total 6.34639 6.40380 0.39325  [+7.8%]  0.0005 (1.92296) (1.95333) (0.16529) [-5.3%]  0.0005
n = 7: total 6.76397 6.82177 0.16607  [+6.1%]  0.0005 (1.83172) (1.85770) (0.13217) [-5.1%]  0.0005
n = 8: total 6.99784 7.16074 0.59902  [+4.7%]  0.0005 (1.70313) (1.75297) (0.14694) [-6.0%]  0.0005

n = 4: total 5.33466 5.45724 0.18488  [-31.2%] 0.0005 (1.85357) (1.87764) (0.11915) [+6.6%]  0.0005
n = 8: total 7.01419 7.16561 0.24266  [+23.8%] 0.0005 (1.71194) (1.76068) (0.17972) [-6.6%]  0.0005
```

Here we see the expected increase in CPU time as we add more cores, along with the improvement in wall-clock time. Notably, the wins from `n = 1` to `n = 4` are steady, presumably coming from usage of the performance cores. As we go beyond, to `n = 5` and above, things initially get slower and then start speeding up again. This is probably because adding efficiency cores initially brings overhead without much benefit, but by the time you get to `n = 8` is has eventually become worth it. For this machine, then, setting `n` equal to the number of cores seems best. One interesting detail about this machine: it is very consistent, if the tight standard deviation (`sd` in the data above) is anything to go by.

##### Codespace (32 "cores")

This is virtualized machine abstracted away from the real hardware. As such, I don't know much about what it _really_ is, nor how judiciously the host operating system is dispensing resources, or how heavily the host may be being loaded by other users, but the machine _does_ report having 32 cores.

On this one, runs were slow enough that I didn't want to do runs at _every_ value of `n` from `1` through to `32`, so I first did a rehearsal using the default value (`n - 32`), then stepped up through the range stopping at various points. I didn't do any duplicate runs for verification at the end:

```
                best    avg       sd      +/-       p      (best)    (avg)      (sd)     +/-      p
n = 32: total 16.93896 18.96201 9.23034 [+0.0%]          (3.85297) (5.16993) (6.21729) [+0.0%]

n = 1:  total 7.20654  7.31142 0.44421  [-159.3%] 0.0005 (7.20594) (7.31123) (0.44549) [+29.3%] 0.0005
n = 2:  total 8.12128  8.26895 0.57564  [+11.6%]  0.0005 (4.75016) (4.89175) (0.46896) [-49.5%] 0.0005
n = 4:  total 9.09852  9.26123 0.58056  [+10.7%]  0.0005 (3.32768) (3.45746) (0.41455) [-41.5%] 0.0005
n = 6:  total 10.25805 10.44102 0.62082 [+11.3%]  0.0005 (2.97186) (3.09319) (0.48270) [-11.8%] 0.0005
n = 8:  total 11.37805 11.60782 0.68811 [+10.1%]  0.0005 (2.86434) (3.00104) (0.55208) [-3.1%]  0.005
n = 10: total 12.66253 13.03118 1.50113 [+10.9%]  0.0005 (2.89058) (3.15046) (1.08616) [+4.7%]  0.0005
n = 12: total 13.13820 13.58685 1.34957 [+4.1%]   0.0005 (2.84314) (3.06918) (0.95240) [-2.6%]  0.01
n = 14: total 13.42511 13.90228 1.93371 [+2.3%]   0.0005 (2.85964) (3.18972) (1.44948) [+3.8%]  0.025
n = 16: total 13.80061 14.62828 2.85644 [+5.0%]   0.0005 (2.92868) (3.45872) (2.27240) [+7.8%]  0.005
n = 24: total 15.92834 17.11139 5.96295 [+14.5%]  0.0005 (3.35290) (4.19543) (4.10931) [+17.6%] 0.0005
n = 32: total 17.00941 19.39369 9.71603 [+11.8%]  0.0005 (3.85935) (5.37582) (6.39681) [+22.0%] 0.0005
```

Here the fastest value was seen at `n = 8` (`3.00s`), but there is very little spread overall between `n = 6` (`3.09s`) and `n = 14` (`3.18s`), `n = 14` being the thread count determined by the heuristic.

##### Ryzen 5950X

From, [the horse's mouth](https://www.amd.com/en/products/cpu/amd-ryzen-9-5950x):

| Item                               | Specification   |
| ---------------------------------- | --------------- |
| # of CPU Cores                     | 16              |
| # of Threads                       | 32              |
| Base Clock                         | 3.4GHz          |
| Max. Boost Clock                   | Up to 4.9GHz    |
| L2 Cache                           | 8MB             |
| L3 Cache                           | 64MB            |
| Default TDP                        | 105W            |
| Processor Technology for CPU Cores | TSMC 7nm FinFET |

This machine reports as having 32 cores. I ran benchmarks at every value from `n = 1` through to `n = 32`, then, for fun, at `n = 64` to show the impact of excessive contention and scheduling overhead, and at `n = 14`, to verify the lowest/fastest measurement:

```
                best    avg      sd      +/-      p      (best)    (avg)      (sd)     +/-      p
n = 1:  total 3.55800 3.59671 0.16373  [+0.1%]         (3.56034) (3.59904) (0.16360) [+0.1%]
n = 2:  total 4.46133 5.00861 1.70429  [+28.2%] 0.0005 (2.64586) (3.09470) (1.17822) [-16.3%] 0.0005
n = 3:  total 5.02967 5.66215 1.13090  [+11.5%] 0.0005 (2.25168) (2.60329) (0.55596) [-18.9%] 0.0005
n = 4:  total 5.41820 6.05616 2.23730  [+6.5%]  0.005  (1.95034) (2.18559) (0.85830) [-19.1%] 0.0005
n = 5:  total 5.75249 6.70559 2.42350  [+9.7%]  0.005  (1.72122) (2.06108) (0.78500) [-6.0%]
n = 6:  total 5.96265 6.46562 2.32349  [-3.7%]         (1.56444) (1.72190) (0.57953) [-19.7%] 0.0005
n = 7:  total 6.15400 6.48435 0.86680  [+0.3%]         (1.51888) (1.58371) (0.22951) [-8.7%]  0.0005
n = 8:  total 6.11471 6.38172 0.52665  [-1.6%]  0.025  (1.39106) (1.45978) (0.15459) [-8.5%]  0.0005
n = 9:  total 6.36723 6.51199 0.55385  [+2.0%]  0.005  (1.35267) (1.40379) (0.22610) [-4.0%]  0.0005
n = 10: total 6.41856 6.89227 2.44719  [+5.5%]  0.005  (1.31911) (1.42273) (0.35845) [+1.3%]
n = 11: total 6.26845 7.05095 3.02979  [+2.3%]         (1.27527) (1.42473) (0.69828) [+0.1%]
n = 12: total 7.32547 7.97052 1.10735  [+11.5%] 0.0005 (1.38303) (1.52546) (0.33466) [+6.6%]  0.005
n = 13: total 7.08992 7.87459 1.48781  [-1.2%]         (1.33758) (1.51104) (0.42037) [-1.0%]
n = 14: total 6.57269 6.84070 0.74083  [-15.1%] 0.0005 (1.24531) (1.32719) (0.41375) [-13.9%] 0.0005
n = 15: total 6.69727 6.99856 0.89338  [+2.3%]  0.005  (1.26382) (1.36944) (0.51258) [+3.1%]  0.025
n = 16: total 7.08280 7.93315 2.16405  [+11.8%] 0.0005 (1.27786) (1.47720) (0.70929) [+7.3%]  0.0005
n = 17: total 7.07534 8.08017 2.54878  [+1.8%]         (1.30906) (1.49576) (0.67297) [+1.2%]
n = 18: total 7.22456 7.76658 2.69393  [-4.0%]  0.05   (1.35255) (1.49348) (0.73250) [-0.2%]
n = 19: total 7.74402 9.07122 2.49869  [+14.4%] 0.0005 (1.39721) (1.71411) (0.85141) [+12.9%] 0.0005
n = 20: total 7.73254 9.09793 4.10608  [+0.3%]         (1.40221) (1.70338) (1.05195) [-0.6%]
n = 21: total 8.10357 8.69010 2.48554  [-4.7%]         (1.42951) (1.57883) (0.54766) [-7.9%]  0.025
n = 22: total 8.16072 9.13355 3.70402  [+4.9%]  0.05   (1.43223) (1.62458) (0.94547) [+2.8%]
n = 23: total 8.47340 9.94706 3.38056  [+8.2%]  0.005  (1.44219) (1.76404) (1.07179) [+7.9%]  0.005
n = 24: total 8.66929 9.20580 2.62669  [-8.1%]  0.005  (1.47809) (1.66661) (0.62186) [-5.8%]  0.025
n = 25: total 8.75008 9.71933 2.34421  [+5.3%]  0.0005 (1.48826) (1.77171) (0.78264) [+5.9%]  0.0005
n = 26: total 8.97025 9.34206 1.31354  [-4.0%]  0.01   (1.48841) (1.69235) (0.91407) [-4.7%]  0.025
n = 27: total 9.17676 10.05765 3.67766 [+7.1%]  0.0005 (1.51732) (1.90032) (1.16532) [+10.9%] 0.005
n = 28: total 9.35312 10.32466 3.05080 [+2.6%]  0.05   (1.52260) (1.81718) (1.10321) [-4.6%]
n = 29: total 9.37094 9.87919 1.45557  [-4.5%]  0.05   (1.55367) (1.77837) (0.80669) [-2.2%]
n = 30: total 9.63241 10.58163 3.05460 [+6.6%]  0.0005 (1.57337) (1.81224) (0.82516) [+1.9%]
n = 31: total 9.69432 10.50730 1.99844 [-0.7%]         (1.62258) (1.99863) (1.04941) [+9.3%]  0.0005
n = 32: total 9.73582 10.84089 3.93477 [+3.1%]         (1.60790) (1.90003) (1.23864) [-5.2%]  0.05

n = 64: total 11.67523 12.54046 1.93124 [+13.6%] 0.0005 (3.09296) (3.61764) (1.06581) [+47.5%] 0.0005

n = 14: total 6.63483 6.85217 0.49835  [-83.0%] 0.0005 (1.24134) (1.30750) (0.28800) [-176.7%] 0.0005
```

On this machine, too, the value determined by the heuristic (ie. `n = 14`) produces an optimal result.

### Scanner benchmarks

#### Watchman

Watchman is extremely sensitive to the specific watches you have configured. For example, with an almost empty `watchman watch-list`:

```
{
    "version": "20220724.130242.0",
    "roots": [
        "/home/wincent/code/wincent/aspects/nvim/files/.config/nvim/pack/bundle/opt/command-t"
    ]
}
```

We get these results (CPU times on left, wall-clock times on right):

```
           best    avg      sd     +/-     p     (best)    (avg)      (sd)     +/-     p
  buffer 0.02478 0.02688 0.01952 [+4.6%] 0.025 (0.02480) (0.02691) (0.01954) [+4.6%] 0.025
    file 0.05376 0.05416 0.00115 [-0.1%]       (0.05396) (0.05433) (0.00125) [-0.1%]
    find 0.02040 0.02102 0.00141 [-2.1%]  0.01 (0.20775) (0.21365) (0.01905) [-0.4%]
     git 0.01841 0.01895 0.00173 [-3.1%] 0.005 (0.22503) (0.22822) (0.00925) [-0.6%] 0.025
      rg 0.02004 0.02067 0.00127 [+0.4%]       (0.55998) (0.56965) (0.02087) [+0.3%]
watchman 0.00181 0.00196 0.00110 [+3.3%]       (0.01737) (0.01890) (0.01657) [-2.1%]
   total 0.14085 0.14365 0.01968 [+0.2%]       (1.09550) (1.11166) (0.03569) [+0.0%]
```

After adding a clone of the Linux kernel repo:

```
{
    "version": "20220724.130242.0",
    "roots": [
        "/home/wincent/code/linux",
        "/home/wincent/code/wincent/aspects/nvim/files/.config/nvim/pack/bundle/opt/command-t"
    ]
}
```

We get this, showing no performance impact:

```
           best    avg      sd     +/-      p     (best)    (avg)      (sd)     +/-     p
  buffer 0.02498 0.02722 0.02081 [+1.2%]        (0.02501) (0.02724) (0.02082) [+1.2%]
    file 0.05407 0.05444 0.00113 [+0.5%] 0.0005 (0.05425) (0.05463) (0.00115) [+0.5%] 0.005
    find 0.02085 0.02126 0.00135 [+1.1%]  0.025 (0.20738) (0.21266) (0.01124) [-0.5%]
     git 0.01886 0.01943 0.00295 [+2.5%]   0.01 (0.22544) (0.22914) (0.01174) [+0.4%]
      rg 0.02007 0.02062 0.00104 [-0.3%]        (0.56322) (0.56808) (0.01408) [-0.3%]
watchman 0.00174 0.00191 0.00084 [-2.8%]        (0.01726) (0.01880) (0.01426) [-0.6%]
   total 0.14204 0.14487 0.02097 [+0.8%]   0.05 (1.10057) (1.11054) (0.03328) [-0.1%]
```

Now, if we add a "parent" watch that spans both of these (ie. watching my home directory):

```
{
    "version": "20220724.130242.0",
    "roots": [
        "/home/wincent",
        "/home/wincent/code/linux",
        "/home/wincent/code/wincent/aspects/nvim/files/.config/nvim/pack/bundle/opt/command-t"
    ]
}
```

We get this, showing that performance really tanks — evidently, the `watch-project` functionality may well be saving memory in the presence of overlapping watches, but we are paying a high price for it (I am not sure whether this is happening inside Watchman itself, which is the one stripping the prefixes off the paths inside the nested watches, or in Command-T; the low CPU times and the high wall-clock times suggest that this is I/O-wait and it's Watchman that is busy):

```
           best    avg      sd      +/-      p     (best)      (avg)      (sd)      +/-      p
  buffer 0.02704 0.03932 0.01764 [+30.8%] 0.0005  (0.02710)  (0.03935) (0.01761) [+30.8%] 0.0005
    file 0.05443 0.05504 0.00191  [+1.1%] 0.0005  (0.05460)  (0.05537) (0.00193)  [+1.3%] 0.0005
    find 0.02089 0.02166 0.00232  [+1.8%]  0.005  (0.21183)  (0.21780) (0.01705)  [+2.4%] 0.0005
     git 0.01913 0.01964 0.00229  [+1.0%]         (0.22554)  (0.23022) (0.01509)  [+0.5%]
      rg 0.02027 0.02075 0.00113  [+0.7%]  0.025  (0.55962)  (0.56885) (0.01878)  [+0.1%]
watchman 0.00488 0.00784 0.00646 [+75.7%] 0.0005 (10.99634) (11.09394) (0.26660) [+99.8%] 0.0005
   total 0.15397 0.16425 0.01712 [+11.8%] 0.0005 (12.10684) (12.20553) (0.27421) [+90.9%] 0.0005
```

## TODO

- Keep adding tests.

  - Add integration tests (seeing as I removed vroom).

- FEAT: toggle mark with space in normal mode to do a multiselection?

- Lots of TODO sprinkled around the code

- DOCS: write docs

- TODO: teach "watchman" scanner not to bail trying to watch root of "/"
