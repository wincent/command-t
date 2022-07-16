return {
  variants = {
    {
      name = 'git',
      source = 'wincent.commandt.private.scanner.git',
      times = 100,
      skip_in_ci = false,
    },
    {
      name = 'rg',
      source = 'wincent.commandt.private.scanner.rg',
      times = 100,
      skip_in_ci = true,
    },
    {
      name = 'watchman',
      source = 'wincent.commandt.private.scanner.watchman',
      -- Not sure why this one is so slow in the suite; it feels fast interactively.
      times = 5,
      skip_in_ci = true,
    },
  },
}
