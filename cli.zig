const std = @import("std");
const globals = @import("globals.zig");
const logger = @import("logger.zig");

//
//TODO: fix handle_args
//

pub const Flags = struct {
    verbose: bool = false,
    dry_run: bool = false,
    threads: u8 = 0,
};

pub const Actions = enum {
    Run,
    Help,
    Version,
};

pub const Args = struct {
    rule: ?[]const u8 = null,
    flags: Flags = .{},
    action: Actions = .Run,
};

pub fn handle_args() !Args {
    var res = Args{};

    const argv = std.os.argv;
    const argc = argv.len;
    var i: usize = 1;

    if (i + 1 > argc) return res;

    res.rule = r: {
        if (argv[i][0] != '-') {
            defer i += 1;
            break :r std.mem.span(argv[i]);
        }
        break :r null;
    };

    while (i < argc) : (i += 1) {
        const arg = std.mem.span(argv[i]);

        if (res.rule == null) {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                res.action = .Help;
                return res;
            } else if (std.mem.eql(u8, arg, "--version")) {
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
                'v' => res.flags.verbose = true,
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
