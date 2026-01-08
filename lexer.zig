const std = @import("std");

const TokenType = enum {
    TOK_EOF,
    TOK_NL,
    TOK_EQ,
    TOK_LBRACE,
    TOK_RBRACE,
    TOK_IDENT,
};

pub const Token = struct {
    type: TokenType,
    str: []const u8,
};

pub const Lexer = struct {
    src: []const u8,
    start_index: usize,
    index: usize,
};

fn advance(lx: *Lexer) ?u8 {
    if (lx.index >= lx.src.len) return null;

    const c: u8 = lx.src[lx.index];
    lx.index += 1;

    return c;
}

fn make_token(tt: TokenType, lx: *Lexer) !Token {
    return Token{.type = tt, .str = lx.src[lx.start_index..lx.index]};
}

pub fn lexer_advance(lx: *Lexer) !Token {
    lx.start_index = lx.index;

    while (true) {
        const c = advance(lx) orelse {
            return make_token(.TOK_EOF, lx);
        };

        switch (c) {
            '\n' => return make_token(.TOK_NL, lx),
            ' ', '\t', '\r',
            '=' => return make_token(.TOK_EQ, lx),
            '{' => return make_token(.TOK_LBRACE, lx),
            '}' => return make_token(.TOK_RBRACE, lx),
            else => {
                    return make_token(.TOK_IDENT, lx);
            }
        }
    }
}

