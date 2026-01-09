const std = @import("std");

const TokenType = enum {
    TOK_EOF,
    TOK_NL,
    TOK_EQ,
    TOK_LBRACE,
    TOK_RBRACE,
    TOK_COLON,
    TOK_COMMENT,
    TOK_STRING,
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

fn peek(lx: *Lexer) ?u8 {
    if (lx.index >= lx.src.len) return null;

    return lx.src[lx.index];
}

fn advance(lx: *Lexer) ?u8 {
    const c = peek(lx) orelse return null;
    lx.index += 1;

    return c;
}

fn make_token(tt: TokenType, lx: *Lexer) Token {
    return Token{ .type = tt, .str = lx.src[lx.start_index..lx.index] };
}

fn handle_comments(lx: *Lexer) Token {
    lx.start_index += 1; // move past #
    while (advance(lx)) |c| if (c == '\n') break;

    return make_token(.TOK_COMMENT, lx);
}

fn handle_strings(lx: *Lexer) !Token {
    const q = lx.src[lx.start_index]; // get opening quote (' or ")

    while (true) {
        const c = advance(lx) orelse return error.UnexpectedEOF;

        if (c == '\n') return error.UnterminatedString;

        if (c == q) break;
    }

    return make_token(.TOK_STRING, lx);
}

fn handle_idents(lx: *Lexer) Token {
    while (peek(lx)) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') break;

        _ = advance(lx);
    }

    return make_token(.TOK_IDENT, lx);
}

pub fn lexer_advance(lx: *Lexer) !Token {
    while (true) {
        lx.start_index = lx.index;

        const c = advance(lx) orelse {
            return make_token(.TOK_EOF, lx);
        };

        switch (c) {
            '\n' => return make_token(.TOK_NL, lx),
            ' ', '\t', '\r' => continue,
            '=' => return make_token(.TOK_EQ, lx),
            '{' => return make_token(.TOK_LBRACE, lx),
            '}' => return make_token(.TOK_RBRACE, lx),
            ':' => return make_token(.TOK_COLON, lx),
            '#' => return handle_comments(lx),
            '\'', '"' => return handle_strings(lx),
            else => {
                if (std.ascii.isAlphanumeric(c) or c == '_') {
                    return handle_idents(lx);
                } else {
                    return error.UnexpectedCharacter;
                }
            },
        }
    }
}
