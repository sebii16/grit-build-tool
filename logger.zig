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

const ansi = struct {
    const reset = "\x1b[0m";
    const bold = "\x1b[1m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const magenta = "\x1b[35m";
};
pub const stdout = std.fs.File.stdout().deprecatedWriter();
pub const stderr = std.fs.File.stderr().deprecatedWriter();

pub const location = struct {
    file: []const u8,
    line: usize,
};

pub fn out(level: LogLevel, line: ?usize, comptime fmt: []const u8, args: anytype) void {
    if (level == .debug and builtin.mode != .Debug) return;

    const sink = switch (level) {
        .info, .debug => stdout,
        .warning, .err, .syntax => stderr,
    };

    const prefix = switch (level) {
        .info => "",
        .warning => ansi.yellow ++ "warning: ",
        .err => ansi.red ++ "error: ",
        .syntax => ansi.red ++ "syntax error: ",
        .debug => ansi.magenta ++ "debug: ",
    };

    if (level == .syntax and line != null) {
        sink.print(ansi.bold ++ "{s}:{d}: {s}" ++ ansi.reset, .{ globals.default_build_file, line orelse 0, prefix }) catch return;
    } else {
        sink.print(ansi.bold ++ "{s}" ++ ansi.reset, .{prefix}) catch return;
    }
    sink.print(fmt ++ "\n", args) catch return;
}
