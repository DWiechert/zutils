# zutils

Zig re-write of coreutils:
- https://en.wikipedia.org/wiki/GNU_Core_Utilities

## Building

Build the project and all utilities with:
```
zig build
```

Run all tests:
```
zig build test --summary all
```

Run individual tests:
```
zig test src/cat.zig
```

## cat

Outputs the contents of a file to stdout.

Usage:
```
./zig-out/bin/cat <file 1> <file 2>
```

Documentation:
```
zig build-lib src/cat.zig -femit-docs
```

## fold

Outputs the contents of a file to stdout with a maximum width of 80 characters per line.

Usage:
```
./zig-out/bin/fold <file>
```

Documentation:
```
zig build-lib src/fold.zig -femit-docs
```

## md5sum

Outputs the MD5 hash of a file to stdout.

Usage:
```
./zig-out/bin/md5sum <file 1> <file 2>
```

## od

Outputs the conts of a file in various formats.

Usage:
```
./zig-out/bin/od <file> <flag>
```

Where `flag` is one of:
* `` - (Empty) Octal formatting
* `-x` - Hex formatting

Documentation:
```
zig build-lib src/od.zig -femit-docs
```

## wc

Counts the number of lines, words, and bytes in a file.

Usage:
```
./zig-out/bin/wc <file 1> <file 2>
```

Documentation:
```
zig build-lib src/wc.zig -femit-docs
```
