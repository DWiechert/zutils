const std = @import("std");

pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const InitOptions = struct {
            initial_capacity: ?usize = null,
            scale_factor: f32 = 1.5, // Scale list by 1.5x
        };

        elements: []T,
        allocator: std.mem.Allocator,
        capacity: usize, // Upper limit of current ArrayList
        scale_factor: f32,

        pub fn init(allocator: std.mem.Allocator, options: InitOptions) Self {
            return Self {
                .elements = &[_]T{},
                .allocator = allocator,
                .capacity = options.initial_capacity orelse 0,
                .scale_factor = options.scale_factor,
            };
        }

        pub fn deinit(self: Self) void {
            // `self` can be an instance since there are no modifications
            if (self.capacity > 0) {
                self.allocator.free(self.elements.ptr[0..self.capacity]);
            }
        }

        pub fn add(self: *Self, element: T) !void {
            // `self` needs to be a pointer because we are modifying the structure
            const curr_length = self.len();

            // Check if underlying memory is already allocated or not
            // If not, request more, otherwise just expand the slice
            if (curr_length == 0 or curr_length >= self.capacity) {
                try self.grow();
            }

            // Expand the slice of the allocated array to hold the new element
            // This just shows a view of the total allocated memory
            // [1][2][3][_][_][_][_][_][_][_]  ← slice only "sees" first 3 items (len = 3)
            //  └─────┘
            //   view
            self.elements = self.elements.ptr[0..curr_length + 1];
            self.elements[curr_length] = element;

            // Successful, return nothing
            return;
        }

        fn grow(self: *Self) !void {
            // Derive the new capacity of the internal array
            // Multiple the current capacity by the scale factor and take the integer ceiling
            std.debug.print("curr_capacity: {d}\t", .{self.capacity});
            const new_capacity = if (self.capacity == 0) 5
            else @as(usize, @intFromFloat(@ceil(@as(f32, @floatFromInt(self.capacity)) * self.scale_factor)));
            std.debug.print("new_capacity: {d}\n", .{new_capacity});

            // Allocating an internal array of `capacity` size
            // [_][_][_][_][_][_][_][_][_][_]  ← 10 items allocated (capacity = 10)
            const new_elements = self.allocator.alloc(T, new_capacity) catch |err| {
                std.debug.print("Error allocating new_elements: {}\n", .{err});
                return err;
            };

            const curr_len = self.len();
            if (curr_len > 0) {
                // Copy elements to new array to fit
                @memcpy(new_elements[0..curr_len], self.elements);
                self.allocator.free(self.elements);
            }

            self.elements.ptr = new_elements.ptr;
            self.capacity = new_capacity;
        }

        pub fn remove(self: *Self) T {
            // `self` needs to be a pointer because we are modifying the structure
            return if (len() == 0) null
                else self.elements[0];
            // TODO: Resize array
            //return error.NotImplemented;
        }

        pub fn len(self: Self) usize {
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
                return if (index < self.list.len()) self.list.elements[index]
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

    try std.testing.expectEqual(@as(usize, 0), list.len());
}

test "empty u8" {
    const list = ArrayList(u8).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
}

test "add i32" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(@as(usize, 2), list.len());
}

test "add u8" {
    var list = ArrayList(u8).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add('h');
    try list.add('e');
    try list.add('l');
    try list.add('l');
    try list.add('o');
    try list.add(' ');
    try list.add('w');
    try list.add('o');
    try list.add('r');
    try list.add('l');
    try list.add('d');
    try std.testing.expectEqual(@as(usize, 11), list.len());
}

test "add u8 with options" {
    var list = ArrayList(u8).init(std.testing.allocator, .{.initial_capacity = 1, .scale_factor = 1.5});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add('h');
    try list.add('e');
    try list.add('l');
    try list.add('l');
    try list.add('o');
    try std.testing.expectEqual(@as(usize, 5), list.len());
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
