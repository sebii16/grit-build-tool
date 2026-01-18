const std = @import("std");
const lexer = @import("lexer.zig");
const globals = @import("globals.zig");
const logger = @import("logger.zig");

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
    default_rule: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn parse_all(self: *Parser) ![]Ast {
        var nodes: std.ArrayList(Ast) = .empty;
        errdefer {
            for (nodes.items) |n| {
                n.cleanup(self.allocator);
            }
            nodes.deinit(self.allocator);

            logger.out(.debug, null, "cleaning up ast", .{});
        }

        var pending_default = false;

        while (true) {
            try self.next_token();

            if (self.curr.type == .TOK_EOF) break;

            if (self.curr.type == .TOK_NL) continue;

            switch (self.curr.type) {
                .TOK_IDENT => {
                    const name = self.curr.value;

                    try self.next_token();

                    switch (self.curr.type) {
                        .TOK_EQ => {
                            if (pending_default) {
                                logger.out(
                                    .syntax,
                                    self.lexer.curr_line,
                                    "@default annotation cannot be called on a variable.",
                                    .{},
                                );
                                return error.SyntaxError;
                            }
                            try self.next_token();
                            const str = try self.expect_and_advance(.TOK_STRING);

                            try nodes.append(self.allocator, Ast{ .VarDecl = .{ .name = name, .value = str.value } });
                        },
                        .TOK_LBRACE => {
                            if (pending_default) {
                                self.default_rule = name;
                                pending_default = false;
                            }

                            var cmds: std.ArrayList([]const u8) = .empty;
                            errdefer cmds.deinit(self.allocator);

                            while (true) {
                                try self.next_token();

                                if (self.curr.type == .TOK_RBRACE) break;

                                if (self.curr.type == .TOK_NL) continue;

                                if (self.curr.type == .TOK_EOF) {
                                    logger.out(.syntax, self.lexer.curr_line, "Expected '}}' got EOF.", .{});
                                    return error.SyntaxError;
                                }

                                const cmd = try self.expect_and_advance(.TOK_STRING);
                                try cmds.append(self.allocator, cmd.value);
                            }

                            try nodes.append(self.allocator, Ast{
                                .RuleDecl = .{ .name = name, .cmds = try cmds.toOwnedSlice(self.allocator) },
                            });
                        },
                        else => {
                            logger.out(.syntax, self.lexer.curr_line, "Expected '=' or '{{' got {s}.", .{@tagName(self.curr.type)});
                            return error.SyntaxError;
                        },
                    }
                },
                .TOK_ANNOTATION => {
                    if (!std.mem.eql(u8, self.curr.value, "default")) {
                        logger.out(.syntax, self.lexer.curr_line, "Unknown annotation: @{s}.", .{self.curr.value});
                        return error.SyntaxError;
                    }

                    if (self.default_rule != null or pending_default == true) {
                        logger.out(.syntax, self.lexer.curr_line, "@default annotation has been called more than once.", .{});
                        return error.SyntaxError;
                    }

                    pending_default = true;
                },
                else => {
                    logger.out(.syntax, self.lexer.curr_line, "Unexpected token: {s}.", .{@tagName(self.curr.type)});
                    return error.SyntaxError;
                },
            }
        }

        if (pending_default) {
            logger.out(.syntax, self.lexer.curr_line, "No rule declaration after @default annotation", .{});
            return error.SyntaxError;
        }

        return nodes.toOwnedSlice(self.allocator);
    }

    fn next_token(self: *Parser) !void {
        self.curr = try self.lexer.next();
    }

    fn expect(self: *Parser, t: lexer.TokenType) !void {
        if (self.curr.type != t) {
            logger.out(.syntax, self.lexer.curr_line, "expected {s}, got {s}.", .{ @tagName(t), @tagName(self.curr.type) });
            return error.SyntaxError;
        }
    }

    fn expect_and_advance(self: *Parser, t: lexer.TokenType) !lexer.Token {
        self.expect(t) catch |e| return e;
        //store current token and advance one
        const tok = self.curr;
        try self.next_token();
        return tok;
    }
};
