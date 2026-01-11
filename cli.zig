const std = @import("std");
const util = @import("util.zig");

pub const Flags = struct {
    verbose: bool = false,
    dry_run: bool = false,
    threads: u6 = 1,
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
        res.action = .Help;
        return res;
    };

    if (std.mem.eql(u8, first, "--h") or std.mem.eql(u8, first, "--help")) {
        res.action = .Help;
        return res;
    } else if (std.mem.eql(u8, first, "--version")) {
        res.action = .Version;
        return res;
    } else {
        res.rule = first;
        while (args.next()) |arg| {
            if (arg.len < 2 or arg[0] != '-') {
                try util.err.print("error: invalid flag: '{s}'\n", .{arg});
                return error.InvalidArgument;
            }
            for (arg[1..], 1..) |c, i| {
                switch (c) {
                    'v' => res.flags.verbose = true,
                    'd' => res.flags.dry_run = true,
                    't' => {
                        if (i + 1 >= arg.len) {
                            try util.err.print("error: missing value for '-t'\n", .{});
                            return error.InvalidArgument;
                        }

                        const num_str = arg[i + 1 ..];
                        res.flags.threads = std.fmt.parseInt(u6, num_str, 10) catch |e| switch (e) {
                            error.InvalidCharacter => {
                                try util.err.print("error: value {s} isn't a number\n", .{num_str});
                                return error.InvalidCharacter;
                            },
                            error.Overflow => {
                                try util.err.print("error: value {s} greated than max ({})\n", .{ num_str, std.math.maxInt(u6) });
                                return error.Overflow;
                            },
                        };
                        break;
                    },
                    else => {
                        try util.err.print("error: invalid flag: '{s}'\n", .{arg});
                        return error.InvalidArgument;
                    },
                }
            }
        }
    }

    return res;
}
