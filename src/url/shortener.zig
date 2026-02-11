const std = @import("std");

const URLEntry = struct {
    ttl_sec: usize,
    url: []const u8,
    short_code: []const u8,
};

pub const Shortener = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    entries: std.ArrayList(URLEntry),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self {
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all strings since we duplicated them
        // when adding to the internal list
        for (self.entries.items) |entry| {
            self.allocator.free(entry.url);
            self.allocator.free(entry.short_code);
        }

        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *Self, url: []const u8) ![]u8 {
        // Generate hash code of the URL
        // Copy url so we manage the life-cycle independently
        const url_copy = try self.allocator.dupe(u8, url);
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(url_copy);
        const hash = hasher.final();

        // Convert hash code to string
        var buf: [16]u8 = undefined;
        const code = try std.fmt.bufPrint(&buf, "{x}", .{hash});

        // Copy code out of buffer so no dangling pointer when function returns
        const code_copy = try self.allocator.dupe(u8, code);

        std.debug.print("url: {s}\tshort_code: {s}\n", .{url_copy, code_copy});

        const entry: URLEntry = .{
            .ttl_sec = 600,
            .url = url_copy,
            .short_code = code_copy,
        };
        try self.entries.append(self.allocator, entry);

        return code_copy;
    }

    pub fn getByShortCode(self: *const Self, short_code: []const u8) ?URLEntry {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, short_code, entry.short_code)) {
                return entry;
            }
        }

        return null;
    }

    pub fn getByUrl(self: *const Self, url: []const u8) ?URLEntry {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, url, entry.url)) {
                return entry;
            }
        }

        return null;
    }

    pub fn write(self: *const Self, writer: anytype) !void {
        // `writer` is `anytype` as Zig does not have interfaces like Java.
        // Instead, whatever is passed as the `writer` is checked at compile
        // time if it has the correct methods or not. If yes, it compiles,
        // if not, it errors.
        try writer.print("{f}", .{std.json.fmt(self.entries.items, .{.whitespace = .indent_1})});
    }

    pub fn read(allocator: std.mem.Allocator, reader: anytype) !Self {
        // `reader` is `anytype` as Zig does not have interfaces like Java.
        // Instead, whatever is passed as the `reader` is checked at compile
        // time if it has the correct methods or not. If yes, it compiles,
        // if not, it errors.
        var shortener = Self.init(allocator);

        // Read all content to string
        const content = try reader.readAllAlloc(allocator, 10 * 1024 * 1024);
        defer allocator.free(content);

        // Parse JSON string
        const parsed = try std.json.parseFromSlice([]URLEntry, allocator, content, .{.allocate = .alloc_if_needed});
        defer parsed.deinit();

        for (parsed.value) |item| {
            // Discard creating short_code
            _ = try shortener.add(item.url);
        }

        return shortener;
    }
};

test "add" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const code = try shortener.add("https://github.com/DWiechert");

    try std.testing.expectEqual(1, shortener.entries.items.len);
    try std.testing.expectEqualStrings("cc303afbc947d04e", code);
}

test "getByShortCode" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const url = "https://github.com/DWiechert";
    const code = try shortener.add(url);

    try std.testing.expectEqual(1, shortener.entries.items.len);
    const entry = shortener.getByShortCode(code).?;
    try std.testing.expectEqualStrings(url, entry.url);
    try std.testing.expectEqualStrings(code, entry.short_code);
    try std.testing.expectEqual(600, entry.ttl_sec);
    try std.testing.expectEqual(null, shortener.getByShortCode("asdf"));
}

test "getByUrl" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const url = "https://github.com/DWiechert";
    const code = try shortener.add(url);

    try std.testing.expectEqual(1, shortener.entries.items.len);
    const entry = shortener.getByUrl(url).?;
    try std.testing.expectEqualStrings(url, entry.url);
    try std.testing.expectEqualStrings(code, entry.short_code);
    try std.testing.expectEqual(600, entry.ttl_sec);
    try std.testing.expectEqual(null, shortener.getByUrl(code));
}

test "write" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    _ = try shortener.add("https://github.com/DWiechert");
    _ = try shortener.add("https://github.com/DWiechert/zutils");

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(std.testing.allocator);
    try shortener.write(buf.writer(std.testing.allocator));

    const expected =
        \\[
        \\ {
        \\  "ttl_sec": 600,
        \\  "url": "https://github.com/DWiechert",
        \\  "short_code": "cc303afbc947d04e"
        \\ },
        \\ {
        \\  "ttl_sec": 600,
        \\  "url": "https://github.com/DWiechert/zutils",
        \\  "short_code": "f261e152eb23b9e5"
        \\ }
        \\]
    ;
    try std.testing.expectEqualStrings(expected, buf.items);
}

test "read" {
    const input =
        \\[
        \\ {
        \\  "url": "https://github.com/DWiechert",
        \\  "short_code": "cc303afbc947d04e",
        \\  "ttl_sec": 600
        \\ },
        \\ {
        \\  "url": "https://github.com/DWiechert/zutils",
        \\  "short_code": "f261e152eb23b9e5",
        \\  "ttl_sec": 600
        \\ }
        \\]
    ;
    var stream = std.io.fixedBufferStream(input);

    var shortener = try Shortener.read(std.testing.allocator, stream.reader());
    defer shortener.deinit();

    try std.testing.expectEqual(2, shortener.entries.items.len);


    const entry1 = shortener.getByShortCode("cc303afbc947d04e").?;
    try std.testing.expectEqualStrings("https://github.com/DWiechert", entry1.url);
    try std.testing.expectEqualStrings("cc303afbc947d04e", entry1.short_code);
    try std.testing.expectEqual(600, entry1.ttl_sec);

    const entry2 = shortener.getByShortCode("f261e152eb23b9e5").?;
    try std.testing.expectEqualStrings("https://github.com/DWiechert/zutils", entry2.url);
    try std.testing.expectEqualStrings("f261e152eb23b9e5", entry2.short_code);
    try std.testing.expectEqual(600, entry2.ttl_sec);
}
