const std = @import("std");
const ArrayList = @import("arraylist.zig").ArrayList;

pub fn HashSet(comptime T: type) type {
    // Alias ArrayList to Bucket for easier tracking
    const Bucket = ArrayList(T);

    return struct {
        const Self = @This();

        // InitOptions

        buckets: ArrayList(Bucket), // List of Lists
        allocator: std.mem.Allocator,
        size: usize,

        pub fn init(allocator: std.mem.Allocator) !Self {
            // "init" returns an error union because it allocates
            // memory in the underlying ArrayList buckets
            var buckets = ArrayList(Bucket).init(allocator, .{});

            // Create some hash buckets on initiatization
            for (0..8) |_| {
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

        pub fn len(self: Self) usize {
            return self.size;
        }
    };
}

test "empty i32" {
    // Need to use "try" here because "init" returns an error union
    var set = try HashSet(i32).init(std.testing.allocator);
    defer set.deinit();

    try std.testing.expectEqual(@as(usize, 0), set.len());
}
