const std = @import("std");

pub const Shortener = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    urls: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self {
            .allocator = allocator,
            .urls = .init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.urls.keyIterator();
        while (iter.next()) |key| {
            // Free the duplicated short code from `add`
            self.allocator.free(key.*);
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
