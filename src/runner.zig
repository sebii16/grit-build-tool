const std = @import("std");
const parser = @import("parser.zig");
const logger = @import("logger.zig");
const cli = @import("cli.zig");
const builtin = @import("builtin");
const globals = @import("globals.zig");
const builtins = @import("builtins.zig");

pub const Config = struct {
    dry_run: bool = false,
    no_expand: bool = false,
    //threads: u8 = 1,
    rule_name: ?[]const u8 = null,
    build_file: []const u8 = globals.default_build_file,
};

fn expand_vars(input: []const u8, rule_name: []const u8, vars: *const parser.VarMap) ![]const u8 {
    var expanded: std.ArrayList(u8) = .empty;
    // defer expanded.deinit(globals.init.arena.allocator());

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
            var value = vars.get(var_name);
            if (value == null) {
                value = try handle_undefined_var(input, rule_name, var_name, start);
            }

            try expanded.appendSlice(globals.init.arena.allocator(), value.?);

            i = end - 1;
            continue;
        }
        expanded.appendAssumeCapacity(c);
    }

    return try expanded.toOwnedSlice(globals.init.arena.allocator());
}

fn handle_undefined_var(full_input: []const u8, rule_name: []const u8, var_name: []const u8, var_start_point: usize) ![]u8 {
    const builtin_var = builtins.get_variables(var_name) orelse {
        var buf: [256]u8 = undefined;
        const w = std.fmt.bufPrint(&buf, "undefined variable in rule '{s}': ", .{rule_name}) catch "";

        const var_pos = 14 + w.len + var_start_point - 1; // var_pos = 14 (len of syntax error prefix) + w.len + start pos of the variable - 1 = pos of "$variable_name"
        const spaces = [_]u8{' '} ** 512;
        const tildes = [_]u8{'~'} ** 128;

        logger.out_adv(.syntax, null, "{s}{s}", .{ w, full_input });
                
        // pad with spaces so '^' aligns at var_pos
        logger.out("{s}^{s}", .{spaces[0..@min(var_pos, spaces.len)], tildes[0..@min(var_name.len, tildes.len)]});
        return error.InvalidVar;
    };

    return builtin_var;
}

pub fn run_build_rule(ast: []const parser.Ast, config: Config, prs: parser.Parser) !void {
    const rule = config.rule_name orelse prs.default_rule orelse {
        logger.out_adv(.err, null, "no build rule selected", .{});
        return error.InvalidRule;
    };

    var vars = try parser.Ast.make_var_map(ast);

    for (ast) |node| {
        switch (node) {
            .RuleDecl => |r| {
                if (!std.mem.eql(u8, r.name, rule)) continue;

                if (r.cmds.len == 0) {
                    logger.out_adv(.warning, null, "build rule '{s}' is empty", .{r.name});
                    return;
                }

                logger.out("executing build rule: '{s}'{s}{s}", .{rule, if (config.no_expand) " [noexpand]" else "",
                    if (config.dry_run) " [dryrun]" else ""});

                for (r.cmds) |cmd| {
                    const expanded = if (!config.no_expand) try expand_vars(cmd, rule, &vars) else cmd;

                    const exit_code = execute_cmd(expanded, config.dry_run) catch |e| {
                        logger.out_adv(.err, null, "execution failed: {s}", .{@errorName(e)});
                        return e;
                    };

                    if (exit_code != 0) {
                        logger.out_adv(.warning, null, "command exited with code {d}", .{exit_code});
                    }
                }
                return;
            },
            else => {},
        }
    }

    logger.out_adv(.err, null, "build rule '{s}' doesn't exist.", .{rule});
    return error.InvalidRule;
}

fn execute_cmd(cmd: []const u8, dry_run: bool) !u8 {
    const args = if (builtin.target.os.tag == .windows)
        [_][]const u8{ "cmd.exe", "/C", cmd }
    else
        [_][]const u8{ "sh", "-c", cmd };

    logger.out("{s}", .{cmd});

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
