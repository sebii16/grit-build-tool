const builtin = @import("builtin");
const std = @import("std");
const runner = @import("runner.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");

pub fn run_commands(items: []const []const u8, config: *const runner.Config) !void {
    if (items.len == 0) return;

    const gpa = globals.init.gpa;

    logger.out_adv(true, .debug, null, "batch size: {d}", .{items.len});
    for (items, 0..) |cmd, i| {
        logger.out_adv(true, .debug, null, "[{d}] {s}", .{ i, cmd });
        logger.out(.info, "{s}", .{cmd});
    }

    if (config.dry_run) return;

    const thread_count = @min(config.threads.?, items.len);
    const threads = try gpa.alloc(std.Thread, thread_count);
    defer gpa.free(threads);

    var index: usize = 0;

    while (index < items.len) {
        const batch_size = @min(thread_count, items.len - index);

        for (0..batch_size) |i| {
            threads[i] = try std.Thread.spawn(.{}, worker, .{items[index + i], batch_size > 1});
        }

        for (0..batch_size) |i| {
            threads[i].join();
        }

        index += batch_size;
    }
}

fn worker(cmd: []const u8, needs_lock: bool) void {
    const res = create_process(cmd) catch |e| {
        if (needs_lock)
            logger.out_locked(.err, "command failed: {s}", .{@errorName(e)})
        else
            logger.out(.err, "command failed: {s}", .{@errorName(e)});

        return;
    };
    defer globals.init.gpa.free(res);

    if (needs_lock) {
        logger.log_mutex.lock(globals.init.io) catch return;
        defer logger.log_mutex.unlock(globals.init.io);
    }
    logger.stdout.interface.writeAll(res) catch return;
}

fn create_process(cmd: []const u8) ![]u8 {
    const gpa = globals.init.gpa;

    const args = if (builtin.target.os.tag == .windows)
        [_][]const u8{ "cmd.exe", "/C", cmd }
    else
        [_][]const u8{ "sh", "-c", cmd };

    const result = try std.process.run(gpa, globals.init.io, .{ .argv = &args });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    return std.mem.concat(gpa, u8, &.{ result.stderr, result.stdout });
}
