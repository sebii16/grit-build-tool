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

pub const Config = struct {
    pub var current: Config = .{};
    
    is_inited: bool = false,

    colors_enabled: bool = false,

    build_file: []const u8 = "",
    default_level: LogLevel = .info,
};

pub fn init(default_level: LogLevel) Config {
    if (Config.current.is_inited) return Config.current;

    const is_tty = std.Io.File.stdout().isTty(globals.init.io) catch false;

    const ansi = if (is_tty and builtin.os.tag == .windows) br: {        
        std.Io.File.stdout().enableAnsiEscapeCodes(globals.init.io) catch {};
        break :br std.Io.File.stdout().supportsAnsiEscapeCodes(globals.init.io) catch false;
    } else is_tty;

    return .{
        .is_inited = true,
        .colors_enabled = ansi,
        .default_level = default_level 
    };
}

pub const Colors = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const magenta = "\x1b[35m";

    pub fn get(comptime code: []const u8) []const u8 {
        return if (Config.current.colors_enabled) code else "";
    }
};

pub fn out(comptime fmt: []const u8, args: anytype) void {
    out_adv(Config.current.default_level, null, fmt, args);
}

pub fn out_adv(level: LogLevel, line: ?usize, comptime fmt: []const u8, args: anytype) void {
    if (level == .debug and builtin.mode != .Debug) return;

    var sink = if (level == .err or level == .warning)
        std.Io.File.stdout().writer(globals.init.io, &.{})
    else
        std.Io.File.stderr().writer(globals.init.io, &.{});

    const prefix = switch (level) {
        .info => "",
        .warning => "warning: ",
        .err => "error: ",
        .syntax => "syntax error: ",
        .debug => "debug: ",
    };

    const color_code = switch (level) {
        .info => "",
        .warning => Colors.get(Colors.yellow),
        .err, .syntax => Colors.get(Colors.red),
        .debug => Colors.get(Colors.magenta),
    };

    var buf: [1024]u8 = undefined;
    const w = if (line != null)
        std.fmt.bufPrint(
            &buf,
            "{s}:{d}: {s}{s}{s}" ++ fmt ++ "\n",
            .{ Config.current.build_file, line.?, color_code, prefix, Colors.get(Colors.reset) } ++ args,
        ) catch return
    else
        std.fmt.bufPrint(
            &buf,
            "{s}{s}{s}" ++ fmt ++ "\n",
            .{ color_code, prefix, Colors.get(Colors.reset) } ++ args,
        ) catch return;

    sink.interface.writeAll(w) catch {};
}
