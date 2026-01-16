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

    var args = std.process.args();
    _ = args.next(); // skip exe name

    const first = args.next() orelse {
        return res;
    };

    if (std.mem.eql(u8, first, "-h") or std.mem.eql(u8, first, "--help")) {
        res.action = .Help;
        return res;
    } else if (std.mem.eql(u8, first, "--version")) {
        res.action = .Version;
        return res;
    } else {
        res.rule = first;
        while (args.next()) |arg| {
            if (arg.len < 2 or arg[0] != '-') {
                logger.out(.err, null, "invalid flag: '{s}'.", .{arg});
                return error.InvalidArgument;
            }
            for (arg[1..], 1..) |c, i| {
                switch (c) {
                    'v' => res.flags.verbose = true,
                    'd' => res.flags.dry_run = true,
                    't' => {
                        if (i + 1 >= arg.len) {
                            logger.out(.err, null, "missing value for '-t'.", .{});
                            return error.InvalidArgument;
                        }

                        const num_str = arg[i + 1 ..];
                        res.flags.threads = std.fmt.parseInt(u8, num_str, 10) catch |e| {
                            switch (e) {
                                error.InvalidCharacter => {
                                    logger.out(.err, null, "value '{s}' isn't a number.", .{num_str});
                                },
                                error.Overflow => {
                                    logger.out(.err, null, "value '{s}' is too big. Max size is {}.", .{ num_str, std.math.maxInt(u8) });
                                },
                            }
                            return e;
                        };
                        break;
                    },
                    else => {
                        logger.out(.err, null, "invalid flag: '{s}'.", .{arg});
                        return error.InvalidArgument;
                    },
                }
            }
        }
    }

    return res;
}
