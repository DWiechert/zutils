//! Implementation of the `wc` command.
//! Reads files and outputs the number of lines, words, and bytes.

const std = @import("std");

/// A structure for storing the total counts of a file
const Counts = struct {
    lines: u32 = 0,
    words: u32 = 0,
    bytes: u64 = 0,
};

/// Gathers counts for the provided file
///
/// Arguments:
/// - `file_path`: Path of the file to count
///
/// Returns:
/// - A `Counts` structure
pub fn wcFile(file_path: [] const u8) !Counts {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buffer: [1024]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const reader = &file_reader.interface;

    var fileCounts: Counts = .{};

    while (reader.takeDelimiterInclusive('\n')) |line| {
        fileCounts.lines += 1;
        fileCounts.bytes += line.len;
        var wordIt = std.mem.tokenizeAny(u8, line, " \t\n");
        while (wordIt.next()) |_| {
            fileCounts.words += 1;
        }

    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }


    return fileCounts;
}

/// Main entry for the `wc` command
/// Prints out the total number of lines, words, and bytes of the provided file(s) to std out
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var totalCounts: Counts = .{};
    var fileCount: u8 = 0;

    while (argsIterator.next()) |entry| {
        const fileCounts = try wcFile(entry);
        try stdout.print("\t{d}\t{d}\t{d}\t{s}\n", .{fileCounts.lines, fileCounts.words, fileCounts.bytes, entry});

        totalCounts.lines += fileCounts.lines;
        totalCounts.words += fileCounts.words;
        totalCounts.bytes += fileCounts.bytes;
        fileCount += 1;
    }

    if (fileCount > 1) {
        try stdout.print("\t{d}\t{d}\t{d}\t{s}\n", .{totalCounts.lines, totalCounts.words, totalCounts.bytes, "total"});
    }

    try stdout.flush();
}
