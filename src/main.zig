const std = @import("std");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const p = @import("parser.zig");
const runner = @import("runner.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");

pub fn main(init: std.process.Init) u8 {
    globals.init = init;

    logger.Config.current = logger.init(.info);

    const args = cli.handle_args() catch return 1;

    logger.Config.current.build_file = args.config.build_file;

    switch (args.action) {
        .Help => {
            logger.out("{s}", .{globals.help_msg});
        },
        .Version => {
            logger.out("{s}", .{globals.ver_msg});
        },
        .List => {
            const src = read_file(args.config.build_file) catch return 1;
            var parser = p.Parser{ .lexer = lexer.Lexer{ .src = src }};
            const ast = parser.parse_all() catch return 1;

            logger.out("available rules:", .{});
            for (ast) |n| {
                switch (n) {
                    .RuleDecl => |r| {
                        logger.out("  {s}", .{r.name});
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

    logger.out_adv(.debug, null, "arena: {} bytes allocated", .{init.arena.queryCapacity()});

    return 0;
}

fn read_file(path: []const u8) ![]u8 {
    const result = std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), globals.init.io, path, globals.init.arena.allocator(), .unlimited) catch {
        logger.out_adv(.err, null, "failed to read '{s}'", .{path});
        return error.ReadFile;
    };

    if (result.len == 0) 
        logger.out_adv(.warning, null, "'{s}' is empty", .{path});

    return result;
}
