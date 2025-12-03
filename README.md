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
