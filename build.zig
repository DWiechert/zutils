const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // A top level step for running all tests.
    // Step can be run via `zig build test`
    const test_step = b.step("test", "Run tests");

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function.

    // zutils commands to build executables for
    const commands = [_][] const u8{
        "cat",
        "md5sum",
        "wc",
        "fold",
        "od",
    };

    // Build executables
    for (commands) |command| {
        // This declares intent for the executable to be installed into the
        // install prefix when running `zig build` (i.e. when executing the default
        // step). By default the install prefix is `zig-out/` but can be overridden
        // by passing `--prefix` or `-p`.
        const exe = b.addExecutable(.{
            .name = command,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("src/{s}.zig", .{command})),
                                          .target = target,
                                          .optimize = optimize,
            }),
        });
        b.installArtifact(exe);

        const exe_tests = b.addTest(.{
            .root_module = exe.root_module,
        });
        const run_exe_tests = b.addRunArtifact(exe_tests);
        test_step.dependOn(&run_exe_tests.step);
    }

    // Build nested libraries
    const nestedLibraries = [_][] const u8 {
        "lib",
        "url",
    };

    for (nestedLibraries) |nestedLibrary| {
        const lib = b.addLibrary(.{
            .name = b.fmt("zutils-{s}", .{nestedLibrary}),
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("src/{s}.zig", .{nestedLibrary})),
                                        .target = target,
                                        .optimize = optimize,
            }),
        });
        b.installArtifact(lib);

        // Build library via `zig build <nested library>` so no need to build executables always
        const lib_step = b.step(nestedLibrary, b.fmt("Build the library - {s}", .{nestedLibrary}));
        lib_step.dependOn(&lib.step);

        // Tests for library
        const lib_tests = b.addTest(.{
            .root_module = lib.root_module,
        });
        const run_lib_tests = b.addRunArtifact(lib_tests);
        test_step.dependOn(&run_lib_tests.step);
    }
}
