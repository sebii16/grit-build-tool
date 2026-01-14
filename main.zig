const std = @import("std");
const util = @import("util.zig");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const g = @import("globals.zig");
const parser = @import("parser.zig");
const builtin = @import("builtin");
const runner = @import("runner.zig");

pub fn main() !void {
    const args = cli.handle_args() catch return;

    switch (args.action) {
        .Help => {
            util.print("{s}", .{g.help_msg});
            return;
        },
        .Version => {
            util.print("{s}", .{g.ver_msg});
            return;
        },
        .Run => {
            var gpa = std.heap.DebugAllocator(.{}){};
            defer {
                const check = gpa.deinit();
                if (check == .leak) @panic("memory leaked");
            }
            const allocator = gpa.allocator();

            const src = util.read_file(g.default_build_file, allocator) catch return;
            defer allocator.free(src);

            var prs = parser.Parser{ .lexer = lexer.Lexer{ .src = src }, .allocator = allocator };
            const ast = prs.parse_all() catch return;

            defer {
                for (ast) |n| {
                    switch (n) {
                        .RuleDecl => |r| {
                            allocator.free(r.cmds);
                        },
                        else => {},
                    }
                }

                allocator.free(ast);
            }

            runner.run_build_rule(args.rule, ast, args, allocator) catch return;
        },
    }
}
