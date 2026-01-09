const std = @import("std");
const util = @import("util.zig");
const lexer = @import("lexer.zig");

pub fn main() !void {
    const args = try util.handle_args();

    if ((args.flags & util.Flags.verbose) != 0) {
        std.debug.print("verbose mode\n", .{});
    }

    if ((args.flags & util.Flags.help) != 0) {
        std.debug.print("print help\n", .{});
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const data = try util.read_file(args.input_file orelse "build.grit", allocator);
    defer allocator.free(data);

    var lx = lexer.Lexer{ .src = data, .index = 0, .start_index = 0 };

    while (true) {
        const tok = try lexer.lexer_advance(&lx);

        std.debug.print("{s}: {s}\n", .{ @tagName(tok.type), tok.str });

        if (tok.type == .TOK_EOF) {
            break;
        }
    }
}
