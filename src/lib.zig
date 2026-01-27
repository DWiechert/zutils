//! ZUtils Library
//! Data structures and algorithms for learning Zig

pub const ArrayList = @import("lib/arraylist.zig").ArrayList;
pub const HashSet = @import("lib/hashset.zig").HashSet;
pub const Benchmark = @import("lib/benchmark.zig").Benchmark;

// This runs all tests from imported files
// when running `zig build test --summary all`
test {
    @import("std").testing.refAllDecls(@This());
}
