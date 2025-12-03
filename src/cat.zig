const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    while (argsIterator.next()) |entry| {
        //std.debug.print("\t\t{s}\n", .{entry});
        var file = try std.fs.cwd().openFile(entry, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var file_reader = file.reader(&buffer);
        const reader = &file_reader.interface;

        while (reader.takeDelimiterInclusive('\n')) |line| {
            std.debug.print("{s}", .{line});
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
    }

}

test "always succeeds" {
    try std.testing.expect(true);
}
