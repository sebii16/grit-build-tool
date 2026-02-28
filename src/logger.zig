const std = @import("std");
const builtin = @import("builtin");
const globals = @import("globals.zig");

pub const LogLevel = enum {
    info,
    warning,
    err,
    debug,
    syntax,
};

pub const ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const magenta = "\x1b[35m";
};

pub const print = std.debug.print;

pub fn out(level: LogLevel, line: ?usize, comptime fmt: []const u8, args: anytype) void {
    if (level == .debug and builtin.mode != .Debug) return;

    const prefix = switch (level) {
        .info => "",
        .warning => ansi.yellow ++ ansi.bold ++ "warning: ",
        .err => ansi.red ++ ansi.bold ++ "error: ",
        .syntax => ansi.red ++ ansi.bold ++ "syntax error: ",
        .debug => ansi.magenta ++ ansi.bold ++ "debug: ",
    };

    if (level == .syntax and line != null) {
        print(
            ansi.bold ++ "{s}:{d}" ++ ansi.reset ++ ": " ++ "{s}" ++ ansi.reset ++ fmt ++ "\n",
            .{ globals.default_build_file, line.?, prefix } ++ args,
        );
    } else {
        print("{s}" ++ ansi.reset ++ fmt ++ "\n", .{prefix} ++ args);
    }
}
