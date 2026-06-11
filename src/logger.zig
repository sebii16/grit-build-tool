const std = @import("std");
const builtin = @import("builtin");
const globals = @import("globals.zig");

pub const LogLevel = enum {
    info,
    debug,
    warning,
    err,
    syntax,
};

pub const color = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const magenta = "\x1b[35m";
};

pub fn out(level: LogLevel, line: ?usize, comptime fmt: []const u8, args: anytype) void {
    if (level == .debug and builtin.mode != .Debug) return;

    var sink = if (level == .err or level == .warning)
        std.Io.File.stdout().writer(globals.init.io, &.{})
    else
        std.Io.File.stderr().writer(globals.init.io, &.{});

    const prefix = switch (level) {
        .info => "",
        .warning => color.yellow ++ color.bold ++ "warning: " ++ color.reset,
        .err => color.red ++ color.bold ++ "error: " ++ color.reset,
        .syntax => color.red ++ color.bold ++ "syntax error: " ++ color.reset,
        .debug => color.magenta ++ color.bold ++ "debug: " ++ color.reset,
    };

    var buf: [1024]u8 = undefined;
    const w = if (line != null)
        std.fmt.bufPrint(
            &buf,
            color.bold ++ "{s}:{d}" ++ color.reset ++ ": {s}" ++ fmt ++ "\n",
            .{ globals.default_build_file, line.?, prefix } ++ args,
        ) catch return
    else
        std.fmt.bufPrint(
            &buf,
            "{s}" ++ fmt ++ "\n",
            .{prefix} ++ args,
        ) catch return;

    sink.interface.writeAll(w) catch {};
}
