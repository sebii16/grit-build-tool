const std = @import("std");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const g = @import("globals.zig");
const p = @import("parser.zig");
const runner = @import("runner.zig");
const logger = @import("logger.zig");
const builtin = @import("builtin");

pub fn main() u8 {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) @panic("memory leaked");
    }
    const allocator = gpa.allocator();
    const args = cli.handle_args(allocator) catch return 1;
    defer if (args.rule_name) |r| {
        logger.out(.debug, null, "cleaning up rule_name", .{});
        allocator.free(r);
    };

    switch (args.action) {
        .Help => {
            logger.out(.info, null, "{s}", .{g.help_msg});
            return 0;
        },
        .Version => {
            logger.out(.info, null, "{s}", .{g.ver_msg});
            logger.out(.debug, null, "debug build", .{});
            return 0;
        },
        .Run => {
           

            const src = read_file(g.default_build_file, allocator) catch return 1;
            defer allocator.free(src);

            var parser = p.Parser{ .lexer = lexer.Lexer{ .src = src }, .allocator = allocator };
            const ast = parser.parse_all() catch return 1;

            defer {
                logger.out(.debug, null, "cleaning up ast", .{});
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

            runner.run_build_rule(ast, args, allocator, parser) catch return 1;
        },
    }

    return 0;
}

fn read_file(comptime path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    return file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        logger.out(.err, null, "failed to read '{s}'.", .{path});
        return error.ReadFile;
    };
}
