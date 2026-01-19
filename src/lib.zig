//! ZUtils Library
//! Data structures and algorithms for learning Zig

pub const ArrayList = @import("lib/arraylist.zig").ArrayList;

// This runs all tests from imported files and double counts
//tests when running `zig build test --summary all`
test {
    @import("std").testing.refAllDecls(@This());
}
