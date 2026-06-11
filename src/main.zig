const std = @import("std");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const p = @import("parser.zig");
const runner = @import("runner.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");

pub fn main(init: std.process.Init) u8 {
    globals.init = init;

    const args = cli.handle_args() catch return 1;

    switch (args.action) {
        .Help => {
            logger.out(.info, null, "{s}", .{globals.help_msg});
        },
        .Version => {
            logger.out(.info, null, "{s}", .{globals.ver_msg});
        },
        .List => {
            const src = read_file(args.config.build_file) catch return 1;
            var parser = p.Parser{ .lexer = lexer.Lexer{ .src = src }};
            const ast = parser.parse_all() catch return 1;

            logger.out(.info, null, logger.color.bold ++ "available rules:" ++ logger.color.reset, .{});
            for (ast) |n| {
                switch (n) {
                    .RuleDecl => |r| {
                        logger.out(.info, null, "  {s}", .{r.name});
                    },
                    else => {},
                }
            }
        },
        .Run => {
            const src = read_file(args.config.build_file) catch return 1;
            var parser = p.Parser{ .lexer = lexer.Lexer{ .src = src }};
            const ast = parser.parse_all() catch return 1;

            runner.run_build_rule(ast, args.config, parser) catch return 1;
        },
    }

    logger.out(.debug, null, "arena: {} bytes allocated", .{init.arena.queryCapacity()});

    return 0;
}

fn read_file(path: []const u8) ![]u8 {
    return std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), globals.init.io, path, globals.init.arena.allocator(), .unlimited) catch {
        logger.out(.err, null, "failed to read '{s}'", .{path});
        return error.ReadFile;
    };
}
