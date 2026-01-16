const std = @import("std");
const lexer = @import("lexer.zig");
const globals = @import("globals.zig");
const logger = @import("logger.zig");

// TODO: add line tracking

const Var = struct {
    name: []const u8,
    value: []const u8,
};

const Rule = struct {
    name: []const u8,
    cmds: [][]const u8,
};

pub const Ast = union(enum) {
    VarDecl: Var,
    RuleDecl: Rule,

    pub fn cleanup(self: Ast, allocator: std.mem.Allocator) void {
        switch (self) {
            .RuleDecl => |r| allocator.free(r.cmds),
            .VarDecl => {},
        }
    }
};

pub const Parser = struct {
    lexer: lexer.Lexer,
    curr: lexer.Token = .{ .value = &[_]u8{}, .type = .TOK__INVALID },
    allocator: std.mem.Allocator,

    pub fn parse_all(self: *Parser) ![]Ast {
        var nodes: std.ArrayList(Ast) = .empty;
        errdefer {
            for (nodes.items) |n| {
                n.cleanup(self.allocator);
            }
            nodes.deinit(self.allocator);

            logger.out(.debug, null, "freed ast", .{});
        }

        while (true) {
            try self.next_token();

            if (self.curr.type == .TOK_EOF) break;

            if (self.curr.type == .TOK_NL or self.curr.type == .TOK_COMMENT) continue;

            const name = try self.expect_and_consume(.TOK_IDENT);

            switch (self.curr.type) {
                .TOK_EQ => {
                    try self.next_token();
                    const value = try self.expect_and_consume(.TOK_STRING);

                    try nodes.append(self.allocator, Ast{ .VarDecl = .{ .name = name.value, .value = value.value } });
                },
                .TOK_LBRACE => {
                    var cmds: std.ArrayList([]const u8) = .empty;
                    errdefer cmds.deinit(self.allocator);

                    while (true) {
                        try self.next_token();

                        if (self.curr.type == .TOK_RBRACE) break;

                        if (self.curr.type == .TOK_NL or self.curr.type == .TOK_COMMENT) continue;

                        if (self.curr.type == .TOK_EOF) {
                            logger.out(.syntax, self.lexer.curr_line, "expected '}}' got 'EOF'.", .{});
                            return error.SyntaxError;
                        }

                        const cmd = try self.expect_and_consume(.TOK_STRING);
                        try cmds.append(self.allocator, cmd.value);
                    }
                    // add all commands and the rule name to the arraylist
                    try nodes.append(self.allocator, Ast{ .RuleDecl = .{ .name = name.value, .cmds = try cmds.toOwnedSlice(self.allocator) } });
                },
                else => {
                    logger.out(.syntax, self.lexer.curr_line, "expected '=' or '{{', got {s}.", .{@tagName(self.curr.type)});
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
            logger.out(.syntax, self.lexer.curr_line, "expected {s}, got {s}.", .{ @tagName(t), @tagName(self.curr.type) });
            return error.SyntaxError;
        }

        //store current token and advance one
        const tok = self.curr;
        try self.next_token();
        return tok;
    }
};
