const std = @import("std");

const Result = struct {
    const Self = @This();

    success: bool,
    iteration: usize,
    nsec: usize = 0,

    pub fn format(self: Self, writer: *std.io.Writer) !void {
        try writer.print("Iteration: {d}\tNSec: {d}\tSuccess: {}", .{self.iteration, self.nsec, self.success});
    }
};

const Results = struct {
    const Self = @This();

    name: [] const u8,
    results: std.ArrayList(Result),

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.results.deinit(allocator);
    }

    pub fn format(self: Self, writer: *std.io.Writer) !void {
        try writer.print("Benchmark {s}\n", .{self.name});
        for (self.results.items) |result| {
            try writer.print("\t{f}\n", .{result});
        }
    }
};

pub const Benchmark = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    timer: std.time.Timer,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self {
            .allocator = allocator,
            .timer = try std.time.Timer.start(),
        };
    }

    pub fn run(self: *Self, name: [] const u8, iterations: usize, func: *const fn() void) !Results {
        std.debug.print("Running benchmark: {s}\n", .{name});

        var results = Results {
            .name = name,
            .results = .empty,
        };

        for (0..iterations) |iteration| {
            self.timer.reset();
            //const s = if (func()) true else |_| false;
            func();
            const nsec = self.timer.read();

            const result = Result{
                .success = true,
                .iteration = (iteration + 1),
                .nsec = nsec,
            };
            try results.results.append(self.allocator, result);
        }

        return results;
    }
};

fn benchEmpty() void {
    // Do nothing - baseline overhead
}

fn benchSimpleLoop() void {
    var sum: u64 = 0;
    for (0..1000) |i| {
        sum += i;
    }
}

test "benchmark empty" {
    var benchmark = try Benchmark.init(std.testing.allocator);

    const name = "min";
    const func = benchEmpty;
    const iterations = 5;
    var results = try benchmark.run(name, iterations, func);
    defer results.deinit(std.testing.allocator);

    std.debug.print("Results:\n{f}", .{results});
}

test "benchmark simple loop" {
    var benchmark = try Benchmark.init(std.testing.allocator);

    const name = "min";
    const func = benchSimpleLoop;
    const iterations = 5;
    var results = try benchmark.run(name, iterations, func);
    defer results.deinit(std.testing.allocator);

    std.debug.print("Results:\n{f}", .{results});
}
