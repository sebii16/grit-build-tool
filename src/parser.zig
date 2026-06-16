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
    //cmds: [][]const u8,
    steps: []Step,
};

const Step = union(enum) {
    parallel: bool,
    cmd: []const u8,
};

pub const VarMap = std.StringHashMapUnmanaged([]const u8);

pub const Ast = union(enum) {
    VarDecl: Var,
    RuleDecl: Rule,

    pub fn make_var_map(self: []const Ast) !VarMap {
        var vars: VarMap = .{};

        var count: u32 = 0;
        for (self) |node| {
            switch (node) {
                .VarDecl => count += 1,
                else => {},
            }
        }

        try vars.ensureTotalCapacity(globals.init.arena.allocator(), count);

        for (self) |node| {
            switch (node) {
                .VarDecl => |v| {
                 if (vars.contains(v.name)) {
                    logger.out_adv(true, .syntax, null, "variable '{s}' redefined", .{v.name});
                     return error.DuplicateVar;
                  }
                 vars.putAssumeCapacity(v.name, v.value);
             },
             else => {},
         }
     }
    
     return vars;
    }
};

pub const Parser = struct {
    lexer: lexer.Lexer,
    curr: lexer.Token = .{ .value = &[_]u8{}, .type = .TOK__INVALID },
    default_rule: ?[]const u8 = null,

    pub fn parse_all(self: *Parser) ![]Ast {
        var nodes: std.ArrayList(Ast) = .empty;

        var pending_default = false;
        try self.next_token();

        while (self.curr.type != .TOK_EOF) {
            switch (self.curr.type) {
                .TOK_IDENT => {
                    const name = self.curr.value;

                    try self.next_token();

                    switch (self.curr.type) {
                        .TOK_EQ => {
                            if (pending_default) {
                                logger.out_adv(true, 
                                    .syntax,
                                    self.lexer.curr_line,
                                    "@default cannot be called here",
                                    .{},
                                );
                                return error.SyntaxError;
                            }
                            try self.next_token();
                            try self.expect(.TOK_STRING);

                            const str = self.curr.value;
                            try self.next_token();

                            try nodes.append(globals.init.arena.allocator(), Ast{ .VarDecl = .{ .name = name, .value = str } });
                        },
                        .TOK_LBRACE => {
                            if (pending_default) {
                                self.default_rule = name;
                                pending_default = false;
                            }

                            try self.next_token();

                            var steps: std.ArrayList(Step) = .empty;

                            while (self.curr.type != .TOK_RBRACE) {
                                if (self.curr.type == .TOK_EOF) {
                                    logger.out_adv(true, .syntax, self.lexer.curr_line, "expected '}}' got 'EOF'", .{});
                                    return error.SyntaxError;
                                }

                                switch (self.curr.type) {
                                    .TOK_STRING => {
                                        const cmd = self.curr.value;
                                        try steps.append(globals.init.arena.allocator(), .{ .cmd = cmd });
                                    },
                                    .TOK_ANNOTATION => {
                                        logger.out_adv(true, .debug, self.lexer.curr_line, "annotation: {s}", .{self.curr.value});
                                        if (std.mem.eql(u8, self.curr.value, "sequential")) {
                                            try steps.append(globals.init.arena.allocator(), .{ .parallel = false });
                                        } else if (std.mem.eql(u8, self.curr.value, "parallel")) {
                                            try steps.append(globals.init.arena.allocator(), .{ .parallel = true });
                                        } else {
                                            logger.out_adv(true, .syntax, self.lexer.curr_line, "unknown annotation '@{s}'", .{self.curr.value});
                                            return error.SyntaxError;
                                        }
                                    },
                                    else => {
                                        logger.out_adv(true, .syntax, self.lexer.curr_line, "unexpected token: '{s}'", .{@tagName(self.curr.type)}); 
                                        return error.SyntaxError;
                                    }
                                }

                                try self.next_token();
                            }

                            try self.next_token();

                            try nodes.append(globals.init.arena.allocator(), Ast{
                                .RuleDecl = .{ .name = name, .steps =  try steps.toOwnedSlice(globals.init.arena.allocator())},
                            });
                        },
                        else => {
                            logger.out_adv(true, .syntax, self.lexer.curr_line, "expected '=' or '{{' got {s}", .{@tagName(self.curr.type)});
                            return error.SyntaxError;
                        },
                    }
                },
                .TOK_ANNOTATION => {
                    if (!std.mem.eql(u8, self.curr.value, "default")) {
                        logger.out_adv(true, .syntax, self.lexer.curr_line, "unknown annotation: '@{s}'", .{self.curr.value});
                        return error.SyntaxError;
                    }

                    if (self.default_rule != null or pending_default == true) {
                        logger.out_adv(true, .syntax, self.lexer.curr_line, "@default can only be called once", .{});
                        return error.SyntaxError;
                    }

                    pending_default = true;
                    try self.next_token();
                },
                else => {
                    logger.out_adv(true, .syntax, self.lexer.curr_line, "unexpected token: '{s}'", .{@tagName(self.curr.type)});
                    return error.SyntaxError;
                },
            }
        }

        if (pending_default) {
            logger.out_adv(true, .syntax, self.lexer.curr_line, "no rule found after @default", .{});
            return error.SyntaxError;
        }

        return nodes.toOwnedSlice(globals.init.arena.allocator());
    }

    fn next_token(self: *Parser) !void {
        while (true) {
            self.curr = try self.lexer.next();
            switch (self.curr.type) {
                .TOK_NL, .TOK_COMMENT => continue,
                else => return,
            }
        }
    }

    fn expect(self: *Parser, t: lexer.TokenType) !void {
        if (self.curr.type != t) {
            logger.out_adv(true, .syntax, self.lexer.curr_line, "expected '{s}', got '{s}'", .{ @tagName(t), @tagName(self.curr.type) });
            return error.SyntaxError;
        }
    }
};
