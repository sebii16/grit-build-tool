const std = @import("std");
const globals = @import("globals.zig");
const logger = @import("logger.zig");
const builtin = @import("builtin");
const runner = @import("runner.zig");

pub const Actions = enum {
    Run,
    Help,
    Version,
    List,
};

pub const ParsedArgs = struct {
    config: runner.Config = .{},
    action: Actions = .Run,
};

pub fn handle_args() !ParsedArgs {
    var res = ParsedArgs{};

    const args = try globals.init.minimal.args.toSlice(globals.init.arena.allocator());

    for (args, 0..) |a, i| {
        logger.out(.debug, null, "argv[{d}]={s}", .{i, a});
    } 

    var i: usize = 1; // skip exe name

    if (i + 1 > args.len) return res;

    res.config.rule_name = if (args[i][0] != '-') r: {
        defer i += 1;
        break :r args[i];
    } else null;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (arg.len < 2 or arg[0] != '-')
            return cli_error(error.InvalidFlag, "invalid flag '{s}'", .{arg});

        if (res.config.rule_name == null) {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                res.action = .Help;
                return res;
            } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
                res.action = .Version;
                return res;
            } else if (std.mem.eql(u8, arg, "--list") or std.mem.eql(u8, arg, "-l")) {
                res.action = .List;
                return res;
            }
        }

        if (std.mem.eql(u8, arg, "--dry") or std.mem.eql(u8, arg, "-d")) {
            res.config.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--noexpand")) {
            res.config.no_expand = true;
        } else if (std.mem.eql(u8, arg, "--file") or std.mem.eql(u8, arg, "-f")) {
            if (i + 1 >= args.len)
                return cli_error(error.FlagMissingValue, "flag '{s}' is missing a value", .{arg});

            i += 1;
            res.config.build_file = args[i];
        } else return cli_error(error.InvalidFlag, "invalid flag '{s}'", .{arg});
    }

    return res;
}

inline fn cli_error(comptime err: anyerror, comptime fmt: []const u8, args: anytype) anyerror {
    logger.out(.err, null, fmt, args);
    return err;
}
