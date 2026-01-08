const std = @import("std");

pub fn read_file(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub const Flags = struct {
    pub const verbose = 1 << 0;
    pub const help = 1 << 1;
};

const Args = struct {
    input_file: ?[]const u8 = null,
    flags: u32 = 0,
};

pub fn handle_args() !Args {
    var args = std.process.args();
    _ = args.next(); // move past exe name

    var args_out = Args{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--file")) {
            args_out.input_file = args.next() orelse {
                std.debug.print("argument '--file' requires a value\n", .{});
                return error.InvalidArgument;
            };
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            args_out.flags |= Flags.verbose;
        } else if (std.mem.eql(u8, arg, "--help")) {
            args_out.flags |= Flags.help;
        } else {
            return error.InvalidArgument;
        }
    }

    return args_out;
}
