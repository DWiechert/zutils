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
            // Need to free the entire allocated capacity, not just
            // the current slice's length
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

        fn calculateNewCapacity(self: *const Self) usize {
            // Read-only pointer to self, no copy
            // By using self: Self, this would copy the struct and allocate extra memory
            // Derive the new capacity of the internal array
            // Multiple the current capacity by the scale factor and take the integer ceiling
            return if (self.capacity == 0) 5
                    else @intFromFloat(@ceil(@as(f32, @floatFromInt(self.capacity)) * self.scale_factor));
        }

        fn grow(self: *Self) !void {
            // Derive the new capacity of the internal array
            // Multiple the current capacity by the scale factor and take the integer ceiling
            const new_capacity = self.calculateNewCapacity();

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

        pub fn remove(self: *Self, index: usize) !T {
            // `self` needs to be a pointer because we are modifying the structure
            const curr_length = self.len();
            if (index >= curr_length) return error.IndexOutOfBounds;

            const element = self.elements[index];

            // Shift everything after index down
            if (index < curr_length - 1) {
                @memcpy(self.elements[index..curr_length - 1], self.elements[index + 1..curr_length]);
            }

            // Shrink the slice of the allocated array to be one smaller
            // This just shows a view of the total allocated memory
            self.elements = self.elements.ptr[0..curr_length - 1];

            return element;
        }

        pub fn get(self: Self, index: usize) !T {
            const curr_length = self.len();
            if (index >= curr_length) return error.IndexOutOfBounds;

            return self.elements[index];
        }

        pub fn len(self: Self) usize {
            // `self` can be an instance since there are no modifications
            return self.elements.len;
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

        /// Returns an iterator over the list.
        /// Note: Modifying the list while iterating (add, remove)
        /// results in undefined behavior.
        pub fn iterator(self: *const Self) Iterator {
            return Iterator {
                .list = self,
                .index = 0,
            };
        }

        const Iterator = struct {
            // This `Self` refers to the outer `ArrayList` class
            // This is a pointer to the list so any modifications
            // (add, remove) are reflected when iterating
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

test "calculateNewCapacity" {
    // No capacity
    const list1 = ArrayList(i32).init(std.testing.allocator, .{});
    try std.testing.expectEqual(5, list1.calculateNewCapacity());

    // Small capacity, default scale factor
    const list2 = ArrayList(i32).init(std.testing.allocator, .{.initial_capacity = 1});
    try std.testing.expectEqual(2, list2.calculateNewCapacity());

    // Small capacity, large scale factor
    const list3 = ArrayList(i32).init(std.testing.allocator, .{.initial_capacity = 2, .scale_factor = 12.0});
    try std.testing.expectEqual(24, list3.calculateNewCapacity());

    // Large capacity, default scale factor
    const list4 = ArrayList(i32).init(std.testing.allocator, .{.initial_capacity = 100});
    try std.testing.expectEqual(150, list4.calculateNewCapacity());
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
    try list.add(' ');
    try list.add('w');
    try list.add('o');
    try list.add('r');
    try list.add('l');
    try list.add('d');
    try std.testing.expectEqual(@as(usize, 11), list.len());
}

test "remove error" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(@as(usize, 2), list.len());
    try std.testing.expectError(error.IndexOutOfBounds, list.remove(3));
    try std.testing.expectEqual(@as(usize, 2), list.len());
}

test "remove first" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(@as(usize, 2), list.len());
    const element = try list.remove(0);
    try std.testing.expectEqual(1, element);
    try std.testing.expectEqual(@as(usize, 1), list.len());
}

test "remove last" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 0), list.len());
    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(@as(usize, 2), list.len());
    const element = try list.remove(1);
    try std.testing.expectEqual(2, element);
    try std.testing.expectEqual(@as(usize, 1), list.len());
}

test "get" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try list.add(1);
    try list.add(2);
    try std.testing.expectEqual(1, list.get(0));
    try std.testing.expectEqual(2, list.get(1));
    try std.testing.expectError(error.IndexOutOfBounds, list.get(2));
}

test "contains i32" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try list.add(1);
    try list.add(2);

    try std.testing.expectEqual(true, list.contains(1));
    try std.testing.expectEqual(true, list.contains(2));
    try std.testing.expectEqual(false, list.contains(3));
}

test "contains u8" {
    var list = ArrayList(u8).init(std.testing.allocator, .{});
    defer list.deinit();

    try list.add('h');
    try list.add('e');
    try list.add('l');
    try list.add('l');
    try list.add('o');

    try std.testing.expectEqual(true, list.contains('h'));
    try std.testing.expectEqual(true, list.contains('l'));
    try std.testing.expectEqual(false, list.contains('w'));
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

test "iterator remove" {
    var list = ArrayList(i32).init(std.testing.allocator, .{});
    defer list.deinit();

    try list.add(1);
    try list.add(2);
    try list.add(3);
    try std.testing.expectEqual(@as(usize, 3), list.len());

    // Iterate once
    var iter = list.iterator();
    try std.testing.expectEqual(1, iter.next().?);
    try std.testing.expectEqual(2, iter.next().?);
    try std.testing.expectEqual(3, iter.next().?);
    try std.testing.expectEqual(null, iter.next());

    // Remove element at index 1 - value 2
    const element = try list.remove(1);
    try std.testing.expectEqual(2, element);
    // List now contains [1, 3]
    try std.testing.expectEqual(@as(usize, 2), list.len());

    // Get new iterator
    var iter2 = list.iterator();

    // Iterate again
    try std.testing.expectEqual(1, iter2.next().?);
    try std.testing.expectEqual(3, iter2.next().?);
    try std.testing.expectEqual(null, iter2.next());

    // Check iterator 1
    iter.reset();
    try std.testing.expectEqual(1, iter.next().?);
    try std.testing.expectEqual(3, iter.next().?);
    try std.testing.expectEqual(null, iter.next());
}
