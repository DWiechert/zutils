const std = @import("std");

pub fn main() void {
    std.debug.print("Hello, {s} from cat!\n", .{"World"});
}

test "always succeeds" {
    try std.testing.expect(true);
}
