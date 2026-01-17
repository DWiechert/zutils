//! Implementation of the `od` command.
//! Reads a file and outputs the data in various formats.

const std = @import("std");

const Errors = error {
    InvalidArgument,
};

const Format = enum {
    octal,
    hex,
};

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

pub fn octalOutput(writer: anytype, file_path: []const u8, format: Format) !void {
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
        try octalOutput(stdout, entry, Format.octal);
        try stdout.flush();
    }
}

test "octalOutput" {
    const expected = try std.fs.cwd().readFileAlloc(
        std.testing.allocator,
        "test_files/od/output_octal.txt",
        1024 * 1024
    );
    defer std.testing.allocator.free(expected);

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try octalOutput(output.writer(std.testing.allocator), "test_files/od/input.txt", Format.octal);

    try std.testing.expectEqualStrings(expected, output.items);
}
