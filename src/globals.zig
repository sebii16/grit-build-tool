const std = @import("std");
const logger = @import("logger.zig");
const builtin = @import("builtin");
const os = @tagName(builtin.target.os.tag);
const arch = @tagName(builtin.target.cpu.arch);
const build_date = if (builtin.mode == .Debug) @embedFile("build_date.txt") else {};

pub var init: std.process.Init = undefined;

pub const default_build_file = "build.grit";

const ver =
    logger.color.bold ++ "grit 0.4.6 (" ++ os ++ " " ++ arch ++ ")" ++ if (builtin.mode == .Debug) logger.color.magenta ++ " [Debug build from " ++ build_date ++ "]" else "";

pub const ver_msg =
    ver ++ logger.color.reset ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    logger.color.bold ++
    \\Usage:
    ++ logger.color.reset ++
    \\
    \\  grit [rule] [build flags]
    \\  grit [build flags]
    \\  grit [global flag]
    \\
    \\If no rule is specified, grit will try to execute the default rule (marked with @default).
    \\
    \\
    ++ logger.color.bold ++
    \\Build flags:
    ++ logger.color.reset ++
    \\
    \\  -d, --dry       Perform a "dry run": Print commands without executing them.
    \\  --noexpand      Don't expand variables.
    ++ logger.color.bold ++
    \\
    \\
    \\Global flags: 
    ++ logger.color.reset ++
    \\
    \\  -h, --help      Print this help message.
    \\  -v, --version   Print version and license information.
    \\  -l, --list      List all available build rules.
    ;
