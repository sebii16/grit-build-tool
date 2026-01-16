const std = @import("std");

pub const default_build_file = "build.grit";
const ver = "grit 0.0.7";

pub const ver_msg =
    ver ++
    \\
    \\Copyright (c) 2026 sebii16
    \\Licensed under the MIT License - see LICENSE for more info.
    ;

pub const help_msg =
    \\usage:
    \\ grit <rule> [-v] [-d] [-t<N>]
    \\ grit <option>
    \\
    \\options: 
    \\ -d            dry run: test a rule without executing it.
    \\ -v            enable verbose output.
    \\ -t<N>         use N threads.
    \\ -h, --help    print this help message.
    \\ --version     print version and license notice.
;
