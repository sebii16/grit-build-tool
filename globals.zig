const std = @import("std");
const logger = @import("logger.zig");

pub const default_build_file = "build.grit";
const ver = logger.ansi.bold ++ "grit 0.0.10" ++ logger.ansi.reset;

pub const ver_msg =
    ver ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    \\usage:
++ logger.ansi.bold ++
    \\
    \\ grit <rule> [-v] [-d] [-t<N>]
    \\ grit <option>
++ logger.ansi.reset ++
    \\
    \\
    \\options: 
    \\ -d            dry run: test a rule without executing it.
    \\ -v            enable verbose output.
    \\ -t<N>         use N threads.
    \\ -h, --help    print this help message.
    \\ --version     print version and license notice.
;
