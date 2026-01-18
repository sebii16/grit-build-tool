const std = @import("std");
const logger = @import("logger.zig");

pub const default_build_file = "build.grit";
const ver = logger.ansi.bold ++ "grit 0.1.0" ++ logger.ansi.reset;

pub const ver_msg =
    ver ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    \\Usage:
++ logger.ansi.bold ++
    \\
    \\  grit [rule] [build flags]
    \\  grit [global flag]
++ logger.ansi.reset ++
    \\ 
    \\
    \\If no rule is specified, the  default rule will be executed (if one is set).
    \\
    \\
++ logger.ansi.bold ++
    \\Build flags:
++ logger.ansi.reset ++
    \\
    \\  -d          Dry run: print commands without executing them.
    \\  -v          Enable verbose output.
    \\  -t<N>       Use N worker threads
++ logger.ansi.bold ++
    \\
    \\
    \\Global flags: 
++ logger.ansi.reset ++
    \\
    \\  -h, --help  Print this help message and exit.
    \\  --version   Print version and license information and exit.
;
