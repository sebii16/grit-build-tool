const std = @import("std");
const builtin = @import("builtin");

pub const out = std.fs.File.stdout().deprecatedWriter();
pub const err = std.fs.File.stderr().deprecatedWriter();

pub fn read_file(path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    const stat = try file.stat();
    if (stat.size == 0)
        return try allocator.alloc(u8, 0);

    return try file.readToEndAlloc(allocator, stat.size);
}
