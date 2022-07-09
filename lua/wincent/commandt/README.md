## Memory model

We want to avoid copying large numbers of strings back and forth.

Similar to existing Command-T model, have a "Finder" instance that maintains a reference to a "Scanner" instance. The scanner can hold a copy of the candidate strings to be searched, and the C code can keep a copy of those strings (ideally, not even a copy). If we must use a copy, then we can use `ffi.gc()` to effectively call our destructor when the scanner goes out of scope.

For returning results back, we only ever have a small number (say, 10), and could easily copy those strings back. We could also return an array of integer indices, that basically say which positions in the scanner's list of candidates matched.

To avoid copying:

Watchman scanner could just keep the BSER block and overwrite it in place, setting NULL bytes to terminate the strings (there is room for this). And return str_t with special field to indicate that these strings aren't to be freed. Not clear whether the overhead would be worth it, but it might be.
