const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "gifsicle",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.force_pic = true;

    lib.addIncludePath(.{ .path = "include" });
    // lib.addIncludePath(.{ .path = "src" });

    const version = "1.94-zig"; // TODO: import version

    const t = lib.target;

    const is32Bit = t.toTarget().ptrBitWidth() == 32;
    const isWindows = t.isWindows();

    const terminalAvailable = true;

    // std.Target.x86.featureSetHas(t.getCpuFeatures(), .simd);
    const config_h = b.addConfigHeader(.{ .style = .{ .cmake = .{ .path = "winconf.h.in" } }, .include_path = "config.h" }, .{
        .GIF_ALLOCATOR_DEFINED = 1,
        .HAVE_INT64_T = 1,
        .X_DISPLAY_MISSING = @intFromBool(isWindows),
        .HAVE_MKSTEMP = @intFromBool(!isWindows),
        .HAVE_POW = 1,
        .HAVE_STRERROR = 1,
        .HAVE_STRTOUL = 1,
        .HAVE_UINT64_T = 1, // search for unused types
        .HAVE_UINTPTR_T = 1,
        .OUTPUT_GIF_TO_TERMINAL = if (terminalAvailable) null else 1,
        .ENABLE_THREADS = @intFromBool(!isWindows), // pthread.h not on windows
        .HAVE_SIMD = 1, // TODO: check target and enable as needed
        .HAVE_VECTOR_SIZE_VECTOR_TYPES = 1,
        //HAVE___BUILTIN_SHUFFLEVECTOR
        //HAVE___SYNC_ADD_AND_FETCH

        .HAVE_STDINT_H = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_UNISTD_H = @intFromBool(terminalAvailable),

        .SIZEOF_FLOAT = 4,
        .SIZEOF_UNSIGNED_INT = 4,
        .SIZEOF_VOID_P = @as(u8, if (is32Bit) 4 else 8),
        .SIZEOF_UNSIGNED_LONG = @as(u8, if (is32Bit or isWindows) 4 else 8),

        .PATHNAME_SEPARATOR = if (isWindows) "\\\\" else "/",
        .RANDOM = "rand",
        .GIF_FREE = "free",
        .IS_WINDOWS = @intFromBool(isWindows),

        .VERSION = version,
    });

    lib.defineCMacro("HAVE_CONFIG_H", "1");

    lib.installHeader("src/gifsicle.h", "gifsicle.h");
    lib.installHeadersDirectory("include", ".");

    lib.addConfigHeader(config_h);
    lib.installConfigHeader(config_h, .{});
    lib.addCSourceFiles(&gifsicle_sources, gifsicle_cflags);
    b.installArtifact(lib);

    ////

    const gifsicle = b.addExecutable(.{
        .name = "gifsicle-cli",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gifsicle.linkLibrary(lib);
    gifsicle.addCSourceFile(.{ .file = .{ .path = "src/gifsicle.c" }, .flags = &.{} });

    // gifsicle.defineCMacro("main", "gifsicle_main");

    const gifview = b.addExecutable(.{
        .name = "gifview-cli",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gifview.linkLibrary(lib);
    gifview.addCSourceFiles(&gifview_sources, &.{});
    gifview.linkSystemLibrary2("X11", .{});
    gifview.defineCMacro("HAVE_CONFIG_H", "1");

    const gifdiff = b.addExecutable(.{
        .name = "gifdiff-cli",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gifdiff.linkLibrary(lib);
    gifdiff.addCSourceFile(.{ .file = .{ .path = "src/gifdiff.c" }, .flags = &.{} });

    b.installArtifact(gifsicle);
    if (!t.isWindows()) b.installArtifact(gifview);
    b.installArtifact(gifdiff);
}

const gifsicle_sources = [_][]const u8{
    "src/clp.c",
    "src/fmalloc.c",
    "src/giffunc.c",
    "src/gifread.c",
    "src/gifunopt.c",
    "src/gifwrite.c",
    "src/merge.c",
    "src/optimize.c",
    "src/quantize.c",
    "src/support.c",
    "src/xform.c",
};

const gifview_sources = [_][]const u8{
    "src/gifview.c",
    "src/gifx.c",
};

const gifsicle_cflags: []const []const u8 = &.{
    // "-std=c89",
    // "-W", "-Wall"
};
