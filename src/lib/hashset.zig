const std = @import("std");
const ArrayList = @import("arraylist.zig").ArrayList;

pub fn HashSet(comptime T: type) type {
    // Alias ArrayList to Bucket for easier tracking
    const Bucket = ArrayList(T);

    return struct {
        const Self = @This();

        pub const InitOptions = struct {
            total_buckets: ?usize = null,
        };

        // InitOptions

        buckets: ArrayList(Bucket), // List of Lists
        allocator: std.mem.Allocator,
        size: usize,

        pub fn init(allocator: std.mem.Allocator, options: InitOptions) !Self {
            // "init" returns an error union because it allocates
            // memory in the underlying ArrayList buckets
            var buckets = ArrayList(Bucket).init(allocator, .{});

            const tb = options.total_buckets orelse 8;

            // Create some hash buckets on initiatization
            for (0..tb) |_| {
                try buckets.add(Bucket.init(allocator, .{}));
            }

            return Self {
                .buckets = buckets,
                .allocator = allocator,
                .size = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            // Free each bucket
            var iter = self.buckets.iterator();
            while (iter.next()) |bucket| {
                bucket.deinit();
            }

            // Free top-level bucket
            self.buckets.deinit();
        }

        pub fn add(self: *Self, element: T) !void {
            const bucket_index = self.getBucket(element);
            var bucket = try self.buckets.getPtr(bucket_index);

            if (bucket.contains(element)) {
                // Already in set, don't allow duplicates
                return;
            }

            try bucket.add(element);
            self.size += 1;
        }

        fn getBucket(self: *const Self, element: T) u64 {
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, element);
            const hash = hasher.final();
            const bucket = hash % self.buckets.len();
            std.debug.print("hash: {d}\tbucket: {d}\n", .{hash, bucket});
            return bucket;
        }

        pub fn remove(self: *Self, element: T) !bool {
            const bucket_index = self.getBucket(element);
            const bucket = try self.buckets.getPtr(bucket_index);

            // Find element in the hash bucket
            var iter = bucket.iterator();
            var index: usize = 0;
            while (iter.next()) |item| {
                if (std.meta.eql(element, item)) {
                    // Remove from bucket
                    _ = try bucket.remove(index);
                    self.size -= 1;
                    return true;
                }
                index += 1;
            }

            // Not found
            return false;
        }

        pub fn len(self: Self) usize {
            return self.size;
        }

        pub fn contains(self: Self, element: T) bool {
            var iter = self.iterator();
            while (iter.next()) |item| {
                if (std.meta.eql(element, item)) {
                    return true;
                }
            }
            return false;
        }

        pub fn iterator(self: *const Self) Iterator {
            return Iterator {
                .set = self,
                .bucket_index = 0,
                .item_index = 0,
            };
        }

        const Iterator = struct {
            set: *const Self,
            bucket_index: usize,
            item_index: usize,

            pub fn next(self: *Iterator) ?T {
                while (self.bucket_index < self.set.buckets.len()) {
                    // Get current bucket
                    // No need to handle error since bounds are checked
                    const bucket = self.set.buckets.get(self.bucket_index) catch unreachable;

                    // Try to get item from current bucket
                    if (self.item_index < bucket.len()) {
                        // Get bucket item
                        // No need to handle error since bounds are checked
                        const item = bucket.get(self.item_index) catch unreachable;
                        self.item_index += 1;
                        return item;
                    }

                    // Current bucket exhausted, increment bucket counter and reset item counter
                    self.bucket_index += 1;
                    self.item_index = 0;
                }

                // All buckets exhausted
                return null;
            }

            pub fn reset(self: *Iterator) void {
                self.bucket_index = 0;
                self.item_index = 0;
            }
        };
    };
}

test "getBucket" {
    // No bucket size
    var set1 = try HashSet(i32).init(std.testing.allocator, .{});
    defer set1.deinit();
    try std.testing.expectEqual(4, set1.getBucket(1));

    // Specified bucket size
    var set2 = try HashSet(i32).init(std.testing.allocator, .{.total_buckets = 7});
    defer set2.deinit();
    try std.testing.expectEqual(1, set2.getBucket(1));
}

test "empty i32" {
    // Need to use "try" here because "init" returns an error union
    var set = try HashSet(i32).init(std.testing.allocator, .{});
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
}


test "empty u8" {
    // Need to use "try" here because "init" returns an error union
    var set = try HashSet(u8).init(std.testing.allocator, .{});
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
}

test "add i32" {
    var set = try HashSet(i32).init(std.testing.allocator, .{});
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
    try set.add(1);
    try set.add(2);
    try set.add(2); // Duplicate, should not increase length
    try std.testing.expectEqual(@as(usize, 2), set.len());
}

test "add u8" {
    var set = try HashSet(u8).init(std.testing.allocator, .{});
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
    try set.add('h');
    try set.add('e');
    try set.add('l');
    try set.add('l'); // Duplicate, should not increase length
    try set.add('o');
    try set.add(' ');
    try set.add('w');
    try set.add('o'); // Duplicate, should not increase length
    try set.add('r');
    try set.add('l'); // Duplicate, should not increase length
    try set.add('d');
    try std.testing.expectEqual(@as(usize, 8), set.len());
}

test "remove" {
    var set = try HashSet(u8).init(std.testing.allocator, .{});
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
    try set.add(1);
    try set.add(2);
    try std.testing.expectEqual(@as(usize, 2), set.len());
    try std.testing.expectEqual(true, set.remove(1));
    try std.testing.expectEqual(@as(usize, 1), set.len());
    try std.testing.expectEqual(false, set.remove(1)); // Remove again, fail
    try std.testing.expectEqual(@as(usize, 1), set.len());
}

test "contains i32" {
    var set = try HashSet(i32).init(std.testing.allocator, .{});
    defer set.deinit();

    try set.add(1);
    try set.add(2);

    try std.testing.expectEqual(true, set.contains(1));
    try std.testing.expectEqual(true, set.contains(2));
    try std.testing.expectEqual(false, set.contains(3));
}

test "contains u8" {
    var set = try HashSet(u8).init(std.testing.allocator, .{});
    defer set.deinit();

    try set.add('h');
    try set.add('e');
    try set.add('l');
    try set.add('l');
    try set.add('o');

    try std.testing.expectEqual(true, set.contains('h'));
    try std.testing.expectEqual(true, set.contains('l'));
    try std.testing.expectEqual(false, set.contains('w'));
}

test "iterator" {
    var set = try HashSet(i32).init(std.testing.allocator, .{});
    defer set.deinit();

    try set.add(1);
    try set.add(2);

    // Iterate once
    var iter = set.iterator();
    try std.testing.expectEqual(1, iter.next().?);
    try std.testing.expectEqual(2, iter.next().?);
    try std.testing.expectEqual(null, iter.next());

    // Reset
    iter.reset();

    // Iterate again
    try std.testing.expectEqual(1, iter.next().?);
    try std.testing.expectEqual(2, iter.next().?);
    try std.testing.expectEqual(null, iter.next());
}
