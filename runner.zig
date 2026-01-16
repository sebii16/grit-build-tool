const std = @import("std");
const parser = @import("parser.zig");
const logger = @import("logger.zig");
const cli = @import("cli.zig");

fn lookup_value(ast: []const parser.Ast, name: []const u8) ?[]const u8 {
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

        // dont expand if $ has a \ infront
        if (c == '\\' and i + 1 < input.len and input[i + 1] == '$') {
            expanded.appendAssumeCapacity('$');
            i += 1;
            continue;
        }

        if (c == '$') {
            const start = i + 1;
            // handle $ followed by syntactically invalid variable name
            if (start >= input.len or !(std.ascii.isAlphanumeric(input[start]) or input[start] == '_')) {
                expanded.appendAssumeCapacity('$');
                continue;
            }

            var end = start;
            while (end < input.len and (std.ascii.isAlphanumeric(input[end]) or input[end] == '_')) : (end += 1) {}

            if (start == end) return error.InvalidVar;

            const value = lookup_value(ast, input[start..end]) orelse {
                const middle = start + (end - start) / 2;
                logger.out(.syntax, null, "{s}", .{input});
                for (0..middle + 14) |_| {
                    try logger.stdout.writeByte(' ');
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

pub fn run_build_rule(rule: []const u8, ast: []const parser.Ast, args: cli.Args, allocator: std.mem.Allocator) !void {
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

    logger.out(.debug, null, "threads: {d}, dry run: {}, verbose output: {}.", .{ threads, args.flags.dry_run, args.flags.verbose });

    for (ast) |node| {
        switch (node) {
            .RuleDecl => |r| {
                if (std.mem.eql(u8, r.name, rule)) {
                    if (r.cmds.len > 0) {
                        for (r.cmds) |cmd| {
                            const expanded = try expand_vars(cmd, ast, allocator);
                            defer {
                                logger.out(.debug, null, "cleaning up expanded cmd", .{});
                                allocator.free(expanded);
                            }

                            logger.out(.debug, null, "{s} -> {s}", .{ cmd, expanded });
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
