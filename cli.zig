const std = @import("std");

pub const Flags = packed struct {
    verbose: bool = false,
    dry_run: bool = false,
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
    const err = std.fs.File.deprecatedWriter(std.fs.File.stderr());

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
                try err.print("error: invalid flag: '{s}'\n", .{arg});
                return error.InvalidArgument;
            }
            for (arg[1..]) |c| {
                switch (c) {
                    'v' => res.flags.verbose = true,
                    'd' => res.flags.dry_run = true,
                    else => {
                        try err.print("error: invalid flag: '{s}'\n", .{arg});
                        return error.InvalidArgument;
                    },
                }
            }
        }
    }

    return res;
}
