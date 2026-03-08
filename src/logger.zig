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

pub const ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const magenta = "\x1b[35m";
};

//pub const print = std.debug.print;

pub const stdout = std.fs.File.stdout();
pub const stderr = std.fs.File.stderr();

pub fn out(level: LogLevel, line: ?usize, comptime fmt: []const u8, args: anytype) void {
    if (level == .debug and builtin.mode != .Debug) return;

    const sink = switch (level) {
        .info, .warning => stdout,
        else => stderr,
    };

    const prefix = switch (level) {
        .info => "",
        .warning => ansi.yellow ++ ansi.bold ++ "warning: " ++ ansi.reset,
        .err => ansi.red ++ ansi.bold ++ "error: " ++ ansi.reset,
        .syntax => ansi.red ++ ansi.bold ++ "syntax error: " ++ ansi.reset,
        .debug => ansi.magenta ++ ansi.bold ++ "debug: " ++ ansi.reset,
    };

    var buf: [512]u8 = undefined;
    const w = if (level == .syntax and line != null)
        std.fmt.bufPrint(
            &buf,
            ansi.bold ++ "{s}:{d}" ++ ansi.reset ++ ": {s}" ++ fmt ++ "\n",
            .{ globals.default_build_file, line.?, prefix } ++ args,
        ) catch return
    else
        std.fmt.bufPrint(
            &buf,
            "{s}" ++ fmt ++ "\n",
            .{prefix} ++ args,
        ) catch return;

    sink.writeAll(w) catch {};
}
