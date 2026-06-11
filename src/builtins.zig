const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});
const globals = @import("globals.zig");
const builtin = @import("builtin");

pub fn get_variables(variable: []const u8) ?[]u8 {
    if (!std.mem.startsWith(u8, variable, "builtin_"))
        return null;

    return switch (std.meta.stringToEnum(enum { date, time, os, arch }, variable[8..]) orelse return null) {
        .date, .time => |t| get_date_time(@intFromEnum(t)),
        .os => globals.init.arena.allocator().dupe(u8, @tagName(builtin.os.tag)) catch null,
        .arch => globals.init.arena.allocator().dupe(u8, @tagName(builtin.cpu.arch)) catch null,
    };
}

fn get_date_time(date_type: u8) ?[]u8 {
    var time: c.time_t = c.time(null);
    const tm = c.localtime(&time) orelse return null;
    var buf: [10]u8 = undefined;

    const res = switch (date_type) {
        0 => std.fmt.bufPrint(&buf, "{d:0>2}.{d:0>2}.{d:0>2}", .{
            @as(u32, @intCast(tm.*.tm_mday)),
            @as(u32, @intCast(tm.*.tm_mon + 1)),
            @as(u32, @intCast(tm.*.tm_year + 1900)),
        }) catch return null,

        1 => std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}", .{
            @as(u32, @intCast(tm.*.tm_hour)),
            @as(u32, @intCast(tm.*.tm_min)),
        }) catch return null,
        else => unreachable
    };

    return globals.init.arena.allocator().dupe(u8, res) catch null;
}
