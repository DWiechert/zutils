const std = @import("std");

pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const InitOptions = struct {
            scale_factor: f32 = 1.5,
        };

        elements: []T,
        allocator: std.mem.Allocator,
        scale_factor: f32,

        pub fn init(allocator: std.mem.Allocator, options:InitOptions) Self {
            return Self {
                .elements = &[_]T{},
                .allocator = allocator,
                .scale_factor = options.scale_factor,
            };
        }

        pub fn deinit(self: Self) void {
            // `self` can be an instance since there are no modifications
            if (self.elements.len > 0) {
                self.allocator.free(self.elements);
            }
        }

        pub fn add(self: *Self, element: T) !void {
            // `self` needs to be a pointer because we are modifying the structure
            const cur_length = self.length();

            const new_elements = self.allocator.alloc(T, cur_length + 1) catch |err| {
                std.debug.print("Error allocating new_elements: {}\n", .{err});
                return err;
            };

            if (cur_length > 0) {
                // Copy elements to new array to fit
                @memcpy(new_elements[0..cur_length], self.elements);
                self.allocator.free(self.elements);
            }

            // Add new element to add
            new_elements[cur_length] = element;
            self.elements = new_elements;

            // Successful, return nothing
            return;
        }

        pub fn remove(self: *Self) T {
            // `self` needs to be a pointer because we are modifying the structure
            return if (length() == 0) null
                else self.elements[0];
            // TODO: Resize array
            //return error.NotImplemented;
        }

        pub fn length(self: Self) usize {
            // `self` can be an instance since there are no modifications
            return self.elements.len;
        }

        pub fn iterator(self: *const Self) Iterator {
            return Iterator {
                .list = self,
                .index = 0,
            };
        }

        const Iterator = struct {
            // This `Self` refers to the outer `ArrayList` class
            list: *const Self,
            index: usize,

            // Cannot use `Self` here because we need to modify
            // the `Iterator`, not the `ArrayList`
            pub fn next(self: *Iterator) ?T {
                const index = self.index;
                self.index += 1;
                return if (index < self.list.length()) self.list.elements[index]
                else null;
            }

            pub fn reset(self: *Iterator) void {
                self.index = 0;
            }
         };
    };
}

test "empty i32" {
    const list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
}

test "empty u8" {
    const list = ArrayList(u8).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
}

test "add i32" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(@as(usize, 2), list.length());
}

test "add u8" {
    var list = ArrayList(u8).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
    try list.add('h');
    try list.add('e');
    try list.add('l');
    try list.add('l');
    try list.add('o');
    try std.testing.expectEqual(@as(usize, 5), list.length());
}

test "iterator" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try list.add(1);
    try list.add(2);

    // Iterate once
    var iter = list.iterator();
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
