const std = @import("std");

pub const Shortener = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    urls: std.StringHashMap([]const u8),
    free_values: bool,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self {
            .allocator = allocator,
            .urls = .init(allocator),
            .free_values = false,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.urls.keyIterator();
        while (iter.next()) |key| {
            // Free the duplicated short code from `add`
            self.allocator.free(key.*);
        }

        if (self.free_values) {
            var iter2 = self.urls.valueIterator();
            while (iter2.next()) |value| {
                self.allocator.free(value.*);
            }
        }

        self.urls.deinit();
    }

    pub fn add(self: *Self, url: []const u8) ![]u8 {
        // Generate hash code of the URL
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(url);
        const hash = hasher.final();

        // Convert hash code to string
        var buf: [16]u8 = undefined;
        const code = try std.fmt.bufPrint(&buf, "{x}", .{hash});

        // Copy code out of buffer so no dangling pointer when function returns
        const code_copy = try self.allocator.dupe(u8, code);

        std.debug.print("url: {s}\tshort_code: {s}\n", .{url, code_copy});

        try self.urls.put(code_copy, url);
        return code_copy;
    }

    pub fn get(self: *const Self, short_code: []const u8) ?[]const u8 {
        return self.urls.get(short_code);
    }

    pub fn findShortCode(self: *const Self, url: []const u8) ?[]const u8 {
        var iter = self.urls.iterator();
        while (iter.next()) |entry| {
            if (std.mem.eql(u8, url, entry.value_ptr.*)) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }


    pub fn write(self: *const Self, writer: anytype) !void {
        // `writer` is `anytype` as Zig does not have interfaces like Java.
        // Instead, whatever is passed as the `writer` is checked at compile
        // time if it has the correct methods or not. If yes, it compiles,
        // if not, it errors.

        var iter = self.urls.iterator();
        while (iter.next()) |entry| {
            try writer.print("{s}={s}\n", .{entry.key_ptr.*, entry.value_ptr.*});
        }
    }

    pub fn read(allocator: std.mem.Allocator, reader: anytype) !Self {
        // `reader` is `anytype` as Zig does not have interfaces like Java.
        // Instead, whatever is passed as the `reader` is checked at compile
        // time if it has the correct methods or not. If yes, it compiles,
        // if not, it errors.

        var shortener = Self.init(allocator);
        // Need to free values when reading from JSON as the values are duplicated
        shortener.free_values = true;

        var buffer: [1024]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            var parts = std.mem.splitScalar(u8, line, '=');
            const code = parts.next() orelse continue;
            const url = parts.next() orelse continue;

            // Need to duplicate the values because `lin` points to the
            // temporary buffer which gets overwritten on each record
            const code_copy = try allocator.dupe(u8, code);
            const url_copy = try allocator.dupe(u8, url);

            try shortener.urls.put(code_copy, url_copy);
        }

        return shortener;
    }
};

test "add" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const code = try shortener.add("https://github.com/DWiechert");

    try std.testing.expectEqual(1, shortener.urls.count());
    try std.testing.expectEqualStrings("cc303afbc947d04e", code);
}

test "get" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const url = "https://github.com/DWiechert";
    const code = try shortener.add(url);

    try std.testing.expectEqual(1, shortener.urls.count());
    try std.testing.expectEqualStrings(url, shortener.get(code).?);
    try std.testing.expectEqual(null, shortener.get("asdf"));
}

test "findShortCode" {
    var shortener = Shortener.init(std.testing.allocator);
    defer shortener.deinit();

    const url = "https://github.com/DWiechert";
    const code = try shortener.add(url);

    try std.testing.expectEqual(1, shortener.urls.count());
    try std.testing.expectEqualStrings(code, shortener.findShortCode(url).?);
    try std.testing.expectEqual(null, shortener.findShortCode(code));
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
        \\cc303afbc947d04e=https://github.com/DWiechert
        \\f261e152eb23b9e5=https://github.com/DWiechert/zutils
        \\
    ;
    try std.testing.expectEqualStrings(expected, buf.items);
}

test "read" {
    const input =
        \\cc303afbc947d04e=https://github.com/DWiechert
        \\f261e152eb23b9e5=https://github.com/DWiechert/zutils
        \\
    ;
    var stream = std.io.fixedBufferStream(input);

    var shortener = try Shortener.read(std.testing.allocator, stream.reader());
    defer shortener.deinit();

    try std.testing.expectEqual(2, shortener.urls.count());
    try std.testing.expectEqualStrings("https://github.com/DWiechert", shortener.get("cc303afbc947d04e").?);
    try std.testing.expectEqualStrings("https://github.com/DWiechert/zutils", shortener.get("f261e152eb23b9e5").?);
}
