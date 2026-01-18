const std = @import("std");
const lexer = @import("lexer.zig");
const globals = @import("globals.zig");
const logger = @import("logger.zig");
const cli = @import("cli.zig");

//
//TODO:
//clean this up
//

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

        while (true) {
            try self.next_token();

            if (self.curr.type == .TOK_EOF) break;

            if (self.curr.type == .TOK_NL or self.curr.type == .TOK_COMMENT) continue;

            const name = try self.expect_and_advance(.TOK_IDENT);

            switch (self.curr.type) {
                .TOK_EQ => {
                    try self.next_token();
                    const value = try self.expect_and_advance(.TOK_STRING);

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

                        if (self.curr.type == .TOK_AT) {
                            try self.next_token();
                            _ = try self.expect(.TOK_DEFAULT);
                            if (self.default_rule != null) {
                                logger.out(.syntax, self.lexer.curr_line, "@default can only be used on one rule", .{});
                                return error.MultipleDefaultRules;
                            }
                            self.default_rule = name.value;
                            continue;
                        }

                        const cmd = try self.expect_and_advance(.TOK_STRING);
                        try cmds.append(self.allocator, cmd.value);
                    }
                    // add all commands and the rule name to the arraylist
                    try nodes.append(self.allocator, Ast{ .RuleDecl = .{ .name = name.value, .cmds = try cmds.toOwnedSlice(self.allocator) } });
                },
                else => {
                    logger.out(.syntax, self.lexer.curr_line, "expected '=', '{{' or ':default', got {s}.", .{@tagName(self.curr.type)});
                    return error.SyntaxError;
                },
            }
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
