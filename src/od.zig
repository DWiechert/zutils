//! Implementation of the `od` command.
//! Reads a file and outputs the data in various formats.

const std = @import("std");

/// Errors that can occur in the `od` command
const Errors = error {
    InvalidArgument,
    MissingFile,
};

/// Formats supported by the `od` command
const Format = enum {
    octal,
    hex,
};

/// Parses the input format
///
/// Arguments:
/// - `arg`: The argument to parse
///
/// Returns:
/// The Format to output in
pub fn parseFormat(arg: u8) !Format {
    return switch (arg) {
        'o' => Format.octal,
        'h' => Format.hex,
        else => Errors.InvalidArgument,
    };
}

test "parseFormat octal" {
    try std.testing.expectEqual(Format.octal, parseFormat('o'));
}

test "parseFormat hex" {
    try std.testing.expectEqual(Format.hex, parseFormat('h'));
}

test "parseFormat error" {
    try std.testing.expectError(Errors.InvalidArgument, parseFormat('a'));
}

/// Writes the contents of `od` to a file
///
/// Arguments:
/// - `writer`: Any writer interface
/// - `file_path`: Path of the file to read
/// - `format`: Format of the output
pub fn odFile(writer: anytype, file_path: []const u8, format: Format) !void {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var offset: u64 = 0;
    var word_buffer: [2]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&word_buffer);
        if (bytes_read == 0) {
            break;
        }

        if (offset % 16 == 0) {
            if (offset > 0) {
                try writer.writeByte('\n');
            }

            try writer.print("{o:0>7}", .{offset});
        }

        // Combine bytes into a 16-bit word using little-endian byte order
        // Little-endian means the least significant byte comes first:
        //   - word_buffer[0] is the low byte (bits 0-7)
        //   - word_buffer[1] is the high byte (bits 8-15)
        // For example, bytes [0x34, 0x12] become word 0x1234
        const word: u16 = if (bytes_read == 2)
            @as(u16, word_buffer[1]) << 8 | @as(u16, word_buffer[0])
        else
            @as(u16, word_buffer[0]);  // If only 1 byte left, treat as low byte

        switch (format) {
            .octal => try writer.print(" {o:0>6}", .{word}),
            .hex => try writer.print(" {x:0>4}", .{word}),
        }

        offset += bytes_read;
    }

    try writer.writeByte('\n');
    try writer.print("{o:0>7}\n", .{offset});  // Print final offset
}

/// Main entry for the `od` command
/// Prints the contents of a file with the supplied formatg
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var argsIterator = try std.process.argsWithAllocator(allocator);
    defer argsIterator.deinit();

    // Skip executable
    _ = argsIterator.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // First argument is file path
    const file_path = argsIterator.next() orelse {
        std.debug.print("Must provide a file path.\n", .{});
        return Errors.MissingFile;
    };

    // Second argument is flag format, strip off the '-'
    const format_arg = argsIterator.next();
    const format = if (format_arg) |flag| try parseFormat(flag[1]) else Format.octal;

    try odFile(stdout, file_path, format);
    try stdout.flush();
}

test "odFile octal" {
    const expected = try std.fs.cwd().readFileAlloc(
        std.testing.allocator,
        "test_files/od/output_octal.txt",
        1024 * 1024
    );
    defer std.testing.allocator.free(expected);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try odFile(output.writer(std.testing.allocator), "test_files/od/input.txt", Format.octal);

    try std.testing.expectEqualStrings(expected, output.items);
}

test "odFile hex" {
    const expected = try std.fs.cwd().readFileAlloc(
        std.testing.allocator,
        "test_files/od/output_hex.txt",
        1024 * 1024
    );
    defer std.testing.allocator.free(expected);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try odFile(output.writer(std.testing.allocator), "test_files/od/input.txt", Format.hex);

    try std.testing.expectEqualStrings(expected, output.items);
}
