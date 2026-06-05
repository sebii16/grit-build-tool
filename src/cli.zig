const std = @import("std");
const globals = @import("globals.zig");
const logger = @import("logger.zig");

pub const Config = struct {
    dry_run: bool = false,
    threads: u8 = 1,
    rule_name: ?[]const u8 = null,
};

pub const Actions = enum {
    Run,
    Help,
    Version,
    List,
};

pub const Args = struct {
    config: Config = .{},
    action: Actions = .Run,
};

fn to_lower(s: []u8) []u8 {
    for (s) |*c| {
        c.* = std.ascii.toLower(c.*);
    }
    return s;
}

pub fn handle_args() !Args {
    var res = Args{};

    const args = try globals.init.minimal.args.toSlice(globals.init.arena.allocator());

    for (args) |a| {
        logger.out(.debug, null, "{s}", .{a});
    } 

    var i: usize = 1; // skip exe name

    if (i + 1 > args.len) return res;

    res.config.rule_name = if (args[i][0] != '-') r: {
        defer i += 1;
        break :r try globals.init.arena.allocator().dupe(u8, args[i]);
    } else null;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

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

        if (arg.len < 2 or arg[0] != '-') {
            logger.out(.err, null, "invalid flag: '{s}'", .{arg});
            return error.InvalidFlag;
        }

        for (arg[1..], 1..) |c, j| {
            switch (c) {
                'd' => res.config.dry_run = true,
                't' => {
                    if (j + 1 >= arg.len) {
                        logger.out(.err, null, "flag '-{c}' is missing a value", .{c});
                        return error.InvalidFlag;
                    }

                    const threads_str = arg[j + 1..];
                    res.config.threads = std.fmt.parseInt(u8, threads_str, 10) catch res: {
                        logger.out(.warning, null, "ignoring thread count '{s}' because it's greater than {d} or not a number", .{threads_str, std.math.maxInt(u8)});
                        break :res 1;
                    };
                    break;
                },
                else => {
                    logger.out(.err, null, "invalid flag: '{s}'", .{arg[j..]});
                    return error.InvalidFlag;
                },
            }
        }
    }

    return res;
}
