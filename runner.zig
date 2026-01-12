const std = @import("std");
const parser = @import("parser.zig");
const util = @import("util.zig");

fn expand_vars(str: []const u8, ast: *const []parser.Ast) !void {
    const allocator = std.heap.page_allocator;
    var vars: std.ArrayList([]const u8) = .empty;
    defer vars.deinit(allocator);

    var pos: usize = 0;
    while (std.mem.indexOfScalar(u8, str[pos..], '$')) |s| {
        const start = pos + s;

        // ignore if escaped
        if (start - 1 > 0 and str[start - 1] == '\\') {
            pos = start + 1;
            continue;
        }

        if (std.mem.indexOfScalar(u8, str[start..], ' ')) |e| {
            const end = start + e;
            pos = end + 1;

            try vars.append(allocator, str[start + 1 .. end]);
        } else {
            try vars.append(allocator, str[start + 1 ..]);
            break;
        }
    }

    for (vars.items) |i| {
        for (ast.*) |n| {
            switch (n) {
                .VarDecl => |r| {
                    if (std.mem.eql(u8, r.name, i)) {
                        util.print_dbg("{s} = {s}", .{ i, r.value });
                    }
                },
                else => {},
            }
        }
    }
}

pub fn run_build_rule(rule: []const u8, ast: *const []parser.Ast, t: usize) !void {
    var threads = t;
    if (threads == 0) {
        threads = blk: {
            const cpus = std.Thread.getCpuCount() catch {
                util.print_warn("failed to get CPU count; defaulting to 1. Use -t<N> to override", .{});
                break :blk 1;
            };
            break :blk cpus;
        };
    }

    for (ast.*) |node| {
        switch (node) {
            .RuleDecl => |r| {
                if (std.mem.eql(u8, r.name, rule)) {
                    for (r.cmds) |cmd| {
                        try expand_vars(cmd, ast);
                    }
                    return;
                }
            },
            else => {},
        }
    }

    util.print_err("build rule '{s}' doesn't exist", .{rule});
    return error.InvalidRule;
}
