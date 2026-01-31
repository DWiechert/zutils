//! Zutils URL Library
//! Functionality related to URL manipulation

pub const Shortener = @import("url/shortener.zig").Shortener;

// This runs all tests from imported files
// when running `zig build test --summary all`
test {
    @import("std").testing.refAllDecls(@This());
}
