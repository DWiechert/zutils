//! Implementation of the `md5sum` command.
//! Computes the MD5 hash of the given files and outputs them.

const std = @import("std");

/// Compute MD5 hash of a string
pub fn md5String(input: []const u8) [16]u8 {
    var hash: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(input, &hash, .{});
    return hash;
}

/// Compute MD5 hash of a file
pub fn md5File(file_path: []const u8) ![16]u8 {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var hasher = std.crypto.hash.Md5.init(.{});

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;
        hasher.update(buffer[0..bytes_read]);
    }

    var hash: [16]u8 = undefined;
    hasher.final(&hash);
    return hash;
}

/// Convert hash bytes to hex string
pub fn hashToHex(hash: [16]u8, output: *[32]u8) void {
    _ = std.fmt.bufPrint(output, "{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        hash[0], hash[1], hash[2],  hash[3],  hash[4],  hash[5],  hash[6],  hash[7],
        hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15],
    }) catch unreachable;
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

    while (argsIterator.next()) |file_path| {
        const hash = try md5File(file_path);

        var hex: [32]u8 = undefined;
        hashToHex(hash, &hex);

        try stdout.writeAll(&hex);
        try stdout.writeAll("  ");
        try stdout.writeAll(file_path);
        try stdout.writeAll("\n");
    }

    try stdout.flush();
}

test "md5 string" {
    const hash = md5String("hello");

    var hex: [32]u8 = undefined;
    hashToHex(hash, &hex);

    // MD5 of "hello" is 5d41402abc4b2a76b9719d911017c592
    try std.testing.expectEqualStrings("5d41402abc4b2a76b9719d911017c592", &hex);
}

test "md5 empty string" {
    const hash = md5String("");

    var hex: [32]u8 = undefined;
    hashToHex(hash, &hex);

    // MD5 of empty string is d41d8cd98f00b204e9800998ecf8427e
    try std.testing.expectEqualStrings("d41d8cd98f00b204e9800998ecf8427e", &hex);
}

test "md5 file" {
    const hash = try md5File("test_files/md5sum/input.txt");

    var hex: [32]u8 = undefined;
    hashToHex(hash, &hex);

    try std.testing.expectEqualStrings("c7253b64411b3aa485924efce6494bb5", &hex);
}
