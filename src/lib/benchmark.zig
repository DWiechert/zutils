const std = @import("std");

const BenchmarkResult = struct {
    const Self = @This();

    iterations: usize,
    total_ns: u64,
    avg_ns: u64,
    min_ns: u64,
    max_ns: u64,
    name: []const u8,

    pub fn format(self: Self, writer: *std.io.Writer) !void {
        try writer.print("Benchmark: {s}\n\tIterations: {d}\tAvg ns: {d}\tTotal ns: {d}\tMin: {d}\tMax: {d}",
                         .{self.name, self.iterations, self.avg_ns, self.total_ns, self.min_ns, self.max_ns});
    }
};

pub const Benchmark = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    results: std.ArrayList(BenchmarkResult),

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self {
            .allocator = allocator,
            .results = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.results.deinit(self.allocator);
    }

    pub fn run(self: *Self, name: [] const u8, iterations: usize, func: *const fn() void) !void {
        var timer = try std.time.Timer.start();
        var min_ms: u64 = std.math.maxInt(u64);
        var max_ns: u64 = 0;
        var total_ns: u64 = 0;

        for (0..iterations) |_| {
            timer.reset();
            func();
            const elapsed = timer.read();

            total_ns += elapsed;
            min_ms = @min(min_ms, elapsed);
            max_ns = @max(max_ns, elapsed);
        }

        const result = BenchmarkResult {
            .name = name,
            .iterations = iterations,
            .total_ns = total_ns,
            .max_ns = max_ns,
            .min_ns = min_ms,
            .avg_ns = (total_ns / iterations),
        };
        try self.results.append(self.allocator, result);
    }

    pub fn report(self: *const Self) void {
        std.debug.print("\n=== Benchmark Report ===\n", .{});
        for (self.results.items) |result| {
            std.debug.print("{f}\n", .{result});
        }
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


test "benchmark simple loop" {
    var bench = try Benchmark.init(std.testing.allocator);
    defer bench.deinit();

    try bench.run("empty", 10000, benchEmpty);
    try bench.run("simple loop", 10000, benchSimpleLoop);

    bench.report();  // Prints summary
}
