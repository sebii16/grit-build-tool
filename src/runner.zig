const std = @import("std");
const parser = @import("parser.zig");
const logger = @import("logger.zig");
const cli = @import("cli.zig");

//
//TODO: clean this up
//

fn lookup_variable(ast: []const parser.Ast, name: []const u8) ?[]const u8 {
    for (ast) |a| {
        switch (a) {
            .VarDecl => |v| {
                if (std.mem.eql(u8, v.name, name)) {
                    return v.value;
                }
            },
            else => {},
        }
    }

    return null;
}

fn expand_vars(input: []const u8, ast: []const parser.Ast, allocator: std.mem.Allocator) ![]u8 {
    var expanded: std.ArrayList(u8) = .empty;
    defer expanded.deinit(allocator);

    try expanded.ensureTotalCapacity(allocator, input.len);

    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];

        // dont expand if $ is escaped with \
        if (c == '\\' and i + 1 < input.len and input[i + 1] == '$') {
            expanded.appendAssumeCapacity('$');
            i += 1;
            continue;
        }

        if (c == '$') {
            const start = i + 1;
            var end = start;

            // increment end as long as character is valid [A-Z/a-z/0-9/_]
            while (end < input.len and (std.ascii.isAlphanumeric(input[end]) or input[end] == '_')) : (end += 1) {}

            // treat as literal $ if its not followed by valid character
            if (start == end) {
                expanded.appendAssumeCapacity('$');
                continue;
            }

            const value = lookup_variable(ast, input[start..end]) orelse {
                const middle = start + (end - start) / 2;
                logger.out(.syntax, null, "{s}", .{input});
                for (0..middle + 14) |_| {
                    try logger.stderr.writeByte(' ');
                }
                logger.out(.info, null, "^ variable undefined.", .{});
                return error.InvalidVar;
            };

            try expanded.appendSlice(allocator, value);
            i = end - 1;
            continue;
        }
        expanded.appendAssumeCapacity(c);
    }

    return try expanded.toOwnedSlice(allocator);
}

pub fn run_build_rule(ast: []const parser.Ast, args: cli.Args, allocator: std.mem.Allocator, prs: parser.Parser) !void {
    // set threads to the number that might have been set by the user, if its not set (standard = 0) or set to 0 try to get cpu count
    // if that fails set it to 1 (single threaded execution) and warn the user
    var threads = args.flags.threads;
    if (threads == 0) {
        threads = res: {
            const cpus = std.Thread.getCpuCount() catch {
                logger.out(.warning, null, "failed to get CPU count; defaulting to 1. Use -t<N> to override.", .{});
                break :res 1;
            };
            const cpus_u8 = @min(cpus, @as(usize, std.math.maxInt(u8)));
            break :res @intCast(cpus_u8);
        };
    }

    const rule = args.rule orelse prs.default_rule orelse {
        logger.out(.err, null, "no build rule selected", .{});
        return error.InvalidRule;
    };

    for (ast) |node| {
        switch (node) {
            .RuleDecl => |r| {
                if (std.mem.eql(u8, r.name, rule)) {
                    if (r.cmds.len > 0) {
                        for (r.cmds) |cmd| {
                            const expanded = try expand_vars(cmd, ast, allocator);
                            defer {
                                allocator.free(expanded);
                            }

                            if (args.flags.dry_run) {
                                logger.out(
                                    .info,
                                    null,
                                    "generated command: {s} [dry run]",
                                    .{expanded},
                                );
                                continue;
                            }

                            const exit_code = execute_cmd(expanded, allocator) catch 1;
                            if (exit_code != 0) {
                                logger.out(.err, null, "command exited with code {d}.", .{exit_code});
                                return error.ExecutionError;
                            }
                        }
                        return;
                    }
                    logger.out(.warning, null, "build rule '{s}' is empty.", .{r.name});
                    return;
                }
            },
            else => {},
        }
    }

    logger.out(.err, null, "build rule '{s}' doesn't exist.", .{rule});
    return error.InvalidRule;
}

fn execute_cmd(cmd: []const u8, allocator: std.mem.Allocator) !u8 {
    var child = std.process.Child.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, allocator);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    try child.spawn();
    const term = try child.wait();

    return switch (term) {
        .Exited => |code| code,
        .Signal => return error.TerminateSignalReceived,
        else => return error.ExecutionError,
    };
}
