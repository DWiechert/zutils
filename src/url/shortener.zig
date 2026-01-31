const std = @import("std");


const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const eql = std.mem.eql;
const Place = struct { lat: f32, long: f32 };

test "hashmap stringify" {
    var map: std.StringHashMap([]const u8) = .init(test_allocator);
    defer map.deinit();

    try map.put("hello", "world");
    try map.put("foo", "bar");
    try map.put("baz", "boo");

    try std.testing.expectEqual(3, map.count());

    var string: std.io.Writer.Allocating = .init(test_allocator);
    defer string.deinit();

    try string.writer.print("{f}", .{std.json.fmt(map, .{.whitespace = .indent_2})});
    std.debug.print("{s}", .{string.written()});
}

test "json parse" {
    const parsed = try std.json.parseFromSlice(
        Place,
        test_allocator,
        \\{ "lat": 40.684540, "long": -74.401422 }
        ,
        .{},
    );
    defer parsed.deinit();

    const place = parsed.value;

    try expect(place.lat == 40.684540);
    try expect(place.long == -74.401422);
}

test "json stringify" {
    const x: Place = .{
        .lat = 51.997664,
        .long = -0.740687,
    };

    var string: std.io.Writer.Allocating = .init(test_allocator);
    defer string.deinit();

    try string.writer.print("{f}", .{std.json.fmt(x, .{})});

    try std.testing.expectEqualStrings(
        \\{"lat":51.99766540527344,"long":-0.7406870126724243}
        , string.written());
}

test "json parse with strings" {
    const User = struct { name: []u8, age: u16 };

    const parsed = try std.json.parseFromSlice(User, test_allocator,
                                               \\{ "name": "Joe", "age": 25 }
                                               , .{});
    defer parsed.deinit();

    const user = parsed.value;

    try expect(eql(u8, user.name, "Joe"));
    try expect(user.age == 25);
}
