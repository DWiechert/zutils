const std = @import("std");

pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();

        elements: []T,
        allocator: std.mem.Allocator,
        scale_factor: f32 = 1.5,

        pub fn init(allocator: std.mem.Allocator) Self {
            // TODO: Add scale_factor as parameter
            return Self {
                .elements = &[_]T{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            // `self` can be an instance since there are no modifications
            if (self.elements.len > 0) {
                self.allocator.free(self.elements);
            }
        }

        pub fn add(self: *Self, element: T) bool {
            // `self` needs to be a pointer because we are modifying the structure
            const cur_length = self.length();

            const new_elements = self.allocator.alloc(T, cur_length + 1) catch |err| {
                //std.debug.print("Error allocating new_elements: {s}", .{err});
                std.debug.print("Error allocating new_elements: {}\n", .{err});
                return false;
            };

            if (cur_length > 0) {
                // Copy elements to new array to fit
                @memcpy(new_elements[0..cur_length], self.elements);
                self.allocator.free(self.elements);
            }

            // Add new element to add
            new_elements[cur_length] = element;
            self.elements = new_elements;

            return true;
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
    };
}

test "empty i32" {
    const list = ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
}

test "empty u8" {
    const list = ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
}

test "add i32" {
    var list = ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
    try std.testing.expectEqual(true, list.add(1));
    try std.testing.expectEqual(true, list.add(2));
    try std.testing.expectEqual(@as(usize, 2), list.length());
}

test "add u8" {
    var list = ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.length());
    try std.testing.expectEqual(true, list.add('h'));
    try std.testing.expectEqual(true, list.add('e'));
    try std.testing.expectEqual(true, list.add('l'));
    try std.testing.expectEqual(true, list.add('l'));
    try std.testing.expectEqual(true, list.add('o'));
    try std.testing.expectEqual(@as(usize, 5), list.length());
}
