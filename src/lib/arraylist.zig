const std = @import("std");

pub fn ArrayList(comptime T: type) type {
    try std.debug.print("Type: {s}", .{T});

    return struct {
        // Your ArrayList implementation here
        const Self = @This();

        elements: []T = .{},


        // TODO: implement

        pub fn add(self: ArrayList, comptime T: type) bool {
            return false;
        }

        pub fn remove(self: ArrayList) type {
            return if (length() == 0) null
                else self.elements[0];
            // TODO: Resize array
            //return error.NotImplemented;
        }

        pub fn length(self: ArrayList) u8 {
            return self.elements.len;
        }
    };
}


test "ArrayList basic operations" {
    // Your tests
    try std.testing.expectEqual(true, true);
}
