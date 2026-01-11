const std = @import("std");
const lexer = @import("lexer.zig");
const util = @import("util.zig");

const Var = struct {
    name: []const u8,
    value: []const u8,
};

const Rule = struct {
    name: []const u8,
    cmds: [][]const u8,
};

pub const Ast = union(enum) {
    VAR: Var,
    RULE: Rule,

    pub fn cleanup(self: Ast, allocator: std.mem.Allocator) void {
        switch (self) {
            .RULE => |r| allocator.free(r.cmds),
            .VAR => {},
        }
    }
};

pub const Parser = struct {
    lexer: lexer.Lexer,
    curr: lexer.Token = .{ .str = &[_]u8{}, .type = .TOK__INVALID },
    allocator: std.mem.Allocator,

    pub fn parse_all(self: *Parser) ![]Ast {
        var nodes: std.ArrayList(Ast) = .empty;
        errdefer {
            for (nodes.items) |n| {
                n.cleanup(self.allocator);
            }
            nodes.deinit(self.allocator);
        }

        while (true) {
            try self.next_token();

            if (self.curr.type == .TOK_EOF) break;

            if (self.curr.type == .TOK_NL) continue;

            const name = try self.expect_and_consume(.TOK_IDENT);

            switch (self.curr.type) {
                .TOK_EQ => {
                    try self.next_token();
                    const value = try self.expect_and_consume(.TOK_STRING);

                    try nodes.append(self.allocator, Ast{ .VAR = .{ .name = name.str, .value = value.str } });
                },
                .TOK_LBRACE => {
                    var cmds: std.ArrayList([]const u8) = .empty;
                    errdefer cmds.deinit(self.allocator);

                    while (true) {
                        try self.next_token();

                        if (self.curr.type == .TOK_RBRACE) break;

                        if (self.curr.type == .TOK_NL) continue;

                        if (self.curr.type == .TOK_EOF) {
                            std.debug.print("syntax error: expected '}}' got 'EOF'\n", .{});
                            return error.SyntaxError;
                        }

                        const cmd = try self.expect_and_consume(.TOK_STRING);
                        try cmds.append(self.allocator, cmd.str);
                    }
                    // add all commands and the rule name to the arraylist
                    try nodes.append(self.allocator, Ast{ .RULE = .{ .name = name.str, .cmds = try cmds.toOwnedSlice(self.allocator) } });
                },
                else => {
                    std.debug.print(
                        "syntax error: expected '=' or '{{', got {s}\n",
                        .{@tagName(self.curr.type)},
                    );
                    return error.SyntaxError;
                },
            }
        }

        return nodes.toOwnedSlice(self.allocator);
    }

    fn next_token(self: *Parser) !void {
        self.curr = try self.lexer.next();
    }

    fn expect_and_consume(self: *Parser, t: lexer.TokenType) !lexer.Token {
        if (self.curr.type != t) {
            util.err.print(
                "syntax error: expected {s}, got {s}\n",
                .{ @tagName(t), @tagName(self.curr.type) },
            ) catch {};
            return error.SyntaxError;
        }

        //store current token and advance one
        const tok = self.curr;
        try self.next_token();
        return tok;
    }
};
