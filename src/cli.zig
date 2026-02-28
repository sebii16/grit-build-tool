const std = @import("std");
const globals = @import("globals.zig");
const logger = @import("logger.zig");

pub const Flags = struct {
    dry_run: bool = false,
    threads: u8 = 0,
};

pub const Actions = enum {
    Run,
    Help,
    Version,
};

pub const Args = struct {
    rule_name: ?[]const u8 = null,
    flags: Flags = .{},
    action: Actions = .Run,
};

pub fn handle_args(allocator: std.mem.Allocator) !Args {
    var res = Args{};

    const args = try std.process.argsAlloc(allocator);
    defer {
        logger.out(.debug, null, "cleaning up argsAlloc'd args", .{});
        std.process.argsFree(allocator, args);
    }
    var i: usize = 1; // skip exe name

    if (i + 1 > args.len) return res;


    errdefer if (res.rule_name) |r| {
        logger.out(.debug, null, "cleaning up rule_name", .{});
        allocator.free(r);
    };

    res.rule_name = r: {
        if (args[i][0] != '-') {
            const copy = try allocator.dupe(u8, args[i]);
            defer i += 1;
            break :r copy;
        }
        break :r null;
    };

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (res.rule_name == null) {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                res.action = .Help;
                return res;
            } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
                res.action = .Version;
                return res;
            }
        }

        if (arg.len < 2 or arg[0] != '-') {
            logger.out(.err, null, "flag '{s}' is invalid.", .{arg});
            return error.InvalidFlag;
        }

        for (arg[1..], 1..) |c, j| {
            switch (c) {
                'd' => res.flags.dry_run = true,
                't' => {
                    if (j + 1 >= arg.len) {
                        logger.out(.err, null, "flag '{c}' is missing a value.", .{c});
                        return error.InvalidFlag;
                    }

                    const num_str = arg[j + 1 ..];
                    res.flags.threads = std.fmt.parseInt(u8, num_str, 10) catch |e| {
                        logger.out(
                            .err,
                            null,
                            "{s} is not a number or bigger than {d}.",
                            .{ num_str, std.math.maxInt(@TypeOf(res.flags.threads)) },
                        );
                        return e;
                    };
                    break;
                },
                else => {
                    logger.out(.err, null, "flag '{c}' is invalid.", .{c});
                    return error.InvalidFlag;
                },
            }
        }
    }

    return res;
}
