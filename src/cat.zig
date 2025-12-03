//! Implementation of the `cat` command.
//! Reads files and outputs them to std out

const std = @import("std");

/// Writes the contents of the provided file to the writer
///
/// Arguments:
/// - `writer`: Any writer interface that supports `writeAll()`
/// - `file_path`: Path of the file to cat
pub fn catFile(writer: anytype, file_path: [] const u8) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    while (reader.takeDelimiterInclusive('\n')) |line| {
        try writer.writeAll(line);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
}

/// Main entry point for the `cat` command
/// Prints out the contents of the provided file(s) to std out
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    while (argsIterator.next()) |entry| {
        try catFile(stdout, entry);
        try stdout.flush();
    }

}

test "catFile outputs test file" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);

    try catFile(output.writer(std.testing.allocator), "test_files/cat/input.txt");
    try std.testing.expectEqualStrings("line 1\nline 2\n", output.items);
}
