const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var src_dir = try std.fs.cwd().openDir("./src", .{ .iterate = true });
    var walker = try src_dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const name = entry.basename[0 .. entry.basename.len - 4];

        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ "src", entry.path }) },
            .target = target,
            .optimize = optimize,
        });

        b.installArtifact(exe);
    }
}
