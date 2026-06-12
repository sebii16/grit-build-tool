const std = @import("std");
const logger = @import("logger.zig");
const builtin = @import("builtin");
const os = @tagName(builtin.target.os.tag);
const arch = @tagName(builtin.target.cpu.arch);
const build_date = if (builtin.mode == .Debug) @embedFile("build_date.txt") else {};

pub var init: std.process.Init = undefined;

pub const default_build_file = "build.grit";

const ver =
    "grit 0.4.7 (" ++ os ++ " " ++ arch ++ ")" ++ if (builtin.mode == .Debug) " [Debug build from " ++ build_date ++ "]" else "";

pub const ver_msg =
    ver ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    \\Usage:
    \\  grit [rule] [build flags]
    \\  grit [build flags]
    \\  grit [global flag]
    \\
    \\If no rule is specified, grit will try to execute the default rule (marked with @default).
    \\
    \\Build flags:
    \\  -d, --dry       Perform a "dry run": Print commands without executing them.
    \\  --noexpand      Don't expand variables.
    \\
    \\Global flags: 
    \\  -h, --help      Print this help message.
    \\  -v, --version   Print version and license information.
    \\  -l, --list      List all available build rules.
    ;
