const std = @import("std");
const lexer = @import("lexer.zig");
const cli = @import("cli.zig");
const p = @import("parser.zig");
const runner = @import("runner.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");

pub fn main(init: std.process.Init) u8 {
    globals.init = init;
 //   const allocator = init.arena.allocator();
 
    errdefer init.arena.deinit();

    const src = read_file(globals.default_build_file) catch return 1;

    var parser = p.Parser{ .lexer = lexer.Lexer{ .src = src }};

    const ast = parser.parse_all() catch return 1;

    const args = cli.handle_args() catch return 1;
    //defer if (args.config.rule_name) |r| allocator.free(r);

    switch (args.action) {
        .Help => {
            logger.out(.info, null, "{s}", .{globals.help_msg});
        },
        .Version => {
            logger.out(.info, null, "{s}", .{globals.ver_msg});
        },
        .List => {
            logger.out(.info, null, logger.ansi.bold ++ "Available rules:" ++ logger.ansi.reset, .{});
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
            runner.run_build_rule(ast, args.config, parser) catch return 1;
        },
    }

    return 0;
}

fn read_file(comptime path: []const u8) ![]u8 {
    return std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), globals.init.io, path, globals.init.arena.allocator(), .unlimited) catch {
        logger.out(.err, null, "failed to read '{s}'", .{path});
        return error.ReadFile;
    };
}
