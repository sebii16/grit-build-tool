const std = @import("std");
const logger = @import("logger.zig");

pub const default_build_file = "build.grit";
const ver = logger.ansi.bold ++ "grit 0.2.0" ++ logger.ansi.reset;

pub const ver_msg =
    ver ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    logger.ansi.bold ++
    \\Usage:
    ++ logger.ansi.reset ++
    \\
    \\  grit [rule] [build flags]
    \\  grit [build flags]
    \\  grit [global flag]
    \\
    \\If no rule is specified, the default rule (marked with @default) is executed.
    \\
    \\
    ++ logger.ansi.bold ++
    \\Build flags:
    ++ logger.ansi.reset ++
    \\
    \\  -d              Dry run: print commands without executing them.
    \\  -t<N>           Use N worker threads
    \\
    \\Build flags can also be combined like this: -dt<N>
    ++ logger.ansi.bold ++
    \\
    \\
    \\Global flags: 
    ++ logger.ansi.reset ++
    \\
    \\  -h, --help      Print this help message and exit.
    \\  -v, --version   Print version and license information and exit.
    ;
