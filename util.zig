const std = @import("std");

pub const out = std.fs.File.stdout().deprecatedWriter();
const err = std.fs.File.stderr().deprecatedWriter();

pub fn read_file(comptime path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        print_err("failed to read 'build.grit.", .{});
        return error.ReadFile;
    };
}

pub inline fn print(comptime fmt: []const u8, args: anytype) void {
    out.print(fmt ++ "\n", args) catch {};
}

pub inline fn print_err(comptime fmt: []const u8, args: anytype) void {
    err.print("error: " ++ fmt ++ "\n", args) catch {};
}

pub inline fn print_dbg(comptime fmt: []const u8, args: anytype) void {
    if (@import("builtin").mode == .Debug) {
        err.print("debug: " ++ fmt ++ "\n", args) catch {};
    }
}

pub inline fn print_warn(comptime fmt: []const u8, args: anytype) void {
    err.print("warning: " ++ fmt ++ "\n", args) catch {};
}
