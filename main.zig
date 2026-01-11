const std = @import("std");
const util = @import("util.zig");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const g = @import("globals.zig");
const parser = @import("parser.zig");
const builtin = @import("builtin");

pub fn main() !void {
    const args = cli.handle_args() catch {
        return;
    };

    switch (args.action) {
        .Help => {
            try util.out.print("{s}\n", .{g.help_msg});
            return;
        },
        .Version => {
            try util.out.print("{s}\n", .{g.ver_msg});
            return;
        },
        .Run => {
            var gpa = std.heap.DebugAllocator(.{}){};
            defer {
                const check = gpa.deinit();
                if (check == .leak) @panic("memory leak");
            }
            const allocator = gpa.allocator();

            const src = util.read_file("build.grit", allocator) catch {
                try util.err.print("error: failed to read 'build.grit\n", .{});
                return;
            };
            defer allocator.free(src);

            var prs = parser.Parser{ .lexer = lexer.Lexer{ .src = src }, .allocator = allocator };
            const ast: []parser.Ast = prs.parse_all() catch return;

            if (builtin.mode == .Debug) {
                for (ast) |n| {
                    switch (n) {
                        .VAR => |v| {
                            std.debug.print("{s} = {s}\n", .{ v.name, v.value });
                        },
                        .RULE => |r| {
                            std.debug.print("{s}:\n", .{r.name});
                            for (r.cmds) |cmd| {
                                std.debug.print("  {s}\n", .{cmd});
                            }
                        },
                    }
                }
            }

            for (ast) |n| {
                switch (n) {
                    .RULE => |r| {
                        allocator.free(r.cmds);
                    },
                    else => {},
                }
            }

            allocator.free(ast);
        },
    }
}
