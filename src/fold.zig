//! Implementation of the `fold` command.
//! Reads a file and outputs to a maximum of 80 characters per line.

const std = @import("std");

/// Writes the contents of the provided file to the writer with at max 80 characters per line
///
/// Arguments:
/// - `writer`: Any writer interface that supports `writeAll()`
/// - `file_path`: Path of the file to fold
pub fn foldFile(writer: anytype, file_path: [] const u8) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    var count: u8 = 0;
    while (reader.takeByte()) |byte| {
        if (byte != '\n') {
            if (count == 80) {
                count = 0;
                try writer.writeByte('\n');
            }
            if (count == 79 and byte ==  ' ') {
                // Do not print space as the last character before the newline
                count += 1;
            } else {
                try writer.writeByte(byte);
                count += 1;
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }
    try writer.writeByte('\n');
}

/// Main entry for the `fold` command
/// Prints the contents of a file to a maximum of 80 characters per line
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    // 80 characters plus newline
    var stdout_buffer: [81]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    while (argsIterator.next()) |entry| {
        try foldFile(stdout, entry);
        try stdout.flush();
    }
}

test "foldFile outputs text to 80 characters" {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try foldFile(output.writer(std.testing.allocator), "test_files/fold/input.txt");

    const expected = try std.fs.cwd().readFileAlloc(
        std.testing.allocator,
        "test_files/fold/output.txt",
        1024 * 1024
    );
    defer std.testing.allocator.free(expected);

    try std.testing.expectEqualStrings(expected, output.items);
}
