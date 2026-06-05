const std = @import("std");
const parser = @import("parser.zig");
const logger = @import("logger.zig");
const cli = @import("cli.zig");
const builtin = @import("builtin");
const globals = @import("globals.zig");
const _c = @cImport({
    @cInclude("time.h");
   // @cInclude("conio.h");
});

fn expand_vars(input: []const u8, rule_name: []const u8, vars: *const parser.VarMap) ![]const u8 {
    var expanded: std.ArrayList(u8) = .empty;
    defer expanded.deinit(globals.init.arena.allocator());

    try expanded.ensureTotalCapacity(globals.init.arena.allocator(), input.len);

    const len = input.len;
    var i: usize = 0;

    while (i < len) : (i += 1) {
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

            const var_name = input[start..end];
            const value = vars.get(var_name);
            if (value == null) {
                try handle_undefined_var(input, rule_name, var_name, start, &expanded);
            } else {
                try expanded.appendSlice(globals.init.arena.allocator(), value.?);
            }
            i = end - 1;
            continue;
        }
        expanded.appendAssumeCapacity(c);
    }

    return try expanded.toOwnedSlice(globals.init.arena.allocator());
}

fn handle_undefined_var(full_input: []const u8, rule_name: []const u8, var_name: []const u8, var_start_point: usize, expanded_arr_list: *std.ArrayList(u8)) !void {
    // handle builtin variables
    if (std.ascii.startsWithIgnoreCase(var_name, "builtin_")) {
        if (std.ascii.eqlIgnoreCase(var_name[8..], "date")) {
            var time: _c.time_t = _c.time(null);
            const tm = _c.localtime(&time).?;
            var buf: [9]u8 = undefined;

            const date = try std.fmt.bufPrint(&buf, "{d:0>2}-{d:0>2}-{d:0>2}", .{
                @as(u32, @intCast(tm.*.tm_mday)),
                @as(u32, @intCast(tm.*.tm_mon + 1)),
                @as(u32, @intCast(@mod(tm.*.tm_year + 1900, 100)))
            });
            try expanded_arr_list.appendSlice(globals.init.arena.allocator(), date);
            return;
        }
    }

    var buf: [256]u8 = undefined;
    const w = std.fmt.bufPrint(&buf, "undefined variable in rule '{s}': ", .{rule_name}) catch "";

    const var_pos = 14 + w.len + var_start_point - 1; // caret_pos = 14 (len of syntax error prefix) + w.len + start pos of the variable - 1 = pos of "$variable_name"
    const spaces = [_]u8{' '} ** 512;
    const tildes = [_]u8{'~'} ** 128;

    logger.out(.syntax, null, "{s}{s}", .{ w, full_input });
                
    // pad with spaces so '^' aligns at var_pos
    logger.out(.info, null, "{s}" ++ logger.ansi.red ++ "^{s}" ++ logger.ansi.reset, .{spaces[0..@min(var_pos, spaces.len)], tildes[0..@min(var_name.len, tildes.len)]});
    return error.InvalidVar;
}

pub fn run_build_rule(ast: []const parser.Ast, config: cli.Config, prs: parser.Parser) !void {
    const rule = config.rule_name orelse prs.default_rule orelse {
        logger.out(.err, null, "no build rule selected", .{});
        return error.InvalidRule;
    };

    var vars = try parser.Ast.make_var_map(ast);
    defer vars.deinit(globals.init.arena.allocator());

    for (ast) |node| {
        switch (node) {
            .RuleDecl => |r| {
                if (!std.mem.eql(u8, r.name, rule)) continue;

                if (r.cmds.len == 0) {
                    logger.out(.warning, null, "build rule '{s}' is empty", .{r.name});
                    return;
                }

                logger.out(.info, null, "executing build rule: '{s}'", .{rule});

                for (r.cmds) |cmd| {
                    const expanded = try expand_vars(cmd, rule, &vars);


                    const exit_code = execute_cmd(expanded, config.dry_run) catch |e| {
                        logger.out(.err, null, "execution failed: {s}", .{@errorName(e)});
                        return e;
                    };

                    if (exit_code != 0) {
                        logger.out(.err, null, "command exited with code {d}", .{exit_code});
                        return error.ExecutionError;
                    }
                }
                return;
            },
            else => {},
        }
    }

    logger.out(.err, null, "build rule '{s}' doesn't exist.", .{rule});
    return error.InvalidRule;
}

fn execute_cmd(cmd: []const u8, dry_run: bool) !u8 {
    const args = if (builtin.target.os.tag == .windows)
        [_][]const u8{ "cmd.exe", "/C", cmd }
    else
        [_][]const u8{ "sh", "-c", cmd };

    logger.out(.info, null, "{s}{s}", .{cmd, if (dry_run) " [dry run]" else ""});

    if (dry_run)
        return 0;

    var child = try std.process.spawn(globals.init.io, .{.argv = args[0..], .stdin = .ignore, .stdout = .inherit, .stderr = .inherit});

    const term = try child.wait(globals.init.io);

    return switch (term) {
        .exited => |code| code,
        .signal => error.TerminateSignalReceived,
        else => error.ExecutionError,
    };
}
