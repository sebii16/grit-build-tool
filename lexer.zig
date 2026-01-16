const std = @import("std");
const logger = @import("logger.zig");
const globals = @import("globals.zig");

pub const TokenType = enum {
    TOK_EOF,
    TOK_NL,
    TOK_EQ,
    TOK_LBRACE,
    TOK_RBRACE,
    TOK_COLON,
    TOK_COMMENT,
    TOK_STRING,
    TOK_IDENT,
    TOK__INVALID,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    src: []const u8,
    start_index: usize = 0,
    index: usize = 0,
    curr_line: usize = 1,

    pub fn next(self: *Lexer) !Token {
        while (true) {
            self.start_index = self.index;

            const c = advance(self) orelse {
                return make_token(.TOK_EOF, self);
            };

            switch (c) {
                '\n' => {
                    self.curr_line += 1;
                    return make_token(.TOK_NL, self);
                },
                ' ', '\t', '\r' => continue,
                '=' => return make_token(.TOK_EQ, self),
                '{' => return make_token(.TOK_LBRACE, self),
                '}' => return make_token(.TOK_RBRACE, self),
                ':' => return make_token(.TOK_COLON, self),
                '#' => return handle_comments(self),
                '\'', '"' => return handle_strings(self),
                else => {
                    if (std.ascii.isAlphanumeric(c) or c == '_') {
                        return handle_idents(self);
                    } else {
                        logger.out(.syntax, self.curr_line, "unexpected character: {c}.", .{c});
                        return error.UnexpectedCharacter;
                    }
                },
            }
        }
    }
};

fn advance(lx: *Lexer) ?u8 {
    if (lx.index >= lx.src.len) return null;
    defer lx.index += 1;

    return lx.src[lx.index];
}

fn make_token(tt: TokenType, lx: *Lexer) Token {
    return Token{ .type = tt, .value = lx.src[lx.start_index..lx.index] };
}

fn handle_comments(lx: *Lexer) Token {
    lx.start_index += 1; // move past #
    while (advance(lx)) |c| {
        if (c == '\n') {
            lx.index -= 1;
            break;
        }
    }

    return make_token(.TOK_COMMENT, lx);
}

fn handle_strings(lx: *Lexer) !Token {
    // get which kind of quote opened the string (' or ")
    const q = lx.src[lx.start_index];

    // move inside the string (over the quote)
    lx.start_index = lx.index;

    while (advance(lx)) |c| {
        if (c == '\n') break;

        if (c == q) {
            // move back inside the string so tok.value wont include the quote
            lx.index -= 1;
            // after making the token go back to the previous index
            defer lx.index += 1;
            return make_token(.TOK_STRING, lx);
        }
    }

    logger.out(.syntax, lx.curr_line, "unterminated string.", .{});
    return error.UnterminatedString;
}

fn handle_idents(lx: *Lexer) Token {
    while (advance(lx)) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            lx.index -= 1;
            break;
        }
    }

    return make_token(.TOK_IDENT, lx);
}
