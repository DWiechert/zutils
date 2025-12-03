const std = @import("std");

pub fn main() void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    while (argsIterator.next()) |entry| {
        std.debug.print("\t\t{s}\n", .{entry});
    }
}

test "always succeeds" {
    try std.testing.expect(true);
}
