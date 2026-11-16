const std = @import("std");
const Expr = @import("expr.zig").Expr;
const lexer = @import("./lexer.zig");

pub const Error = error{
    ExpectedRparen,
    ExpectedIdentifier,
    ExpectedDot,
    UnexpectedToken,
} || std.mem.Allocator.Error || std.mem.PrintError;

pub const Diagnostics = struct {
    _message_buffer: [256]u8 = @splat(0),
    message: []u8 = &.{},
};

const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    tokens: []const lexer.Token,
    pos: usize = 0,

    pub fn init(allocator: std.mem.Allocator, tokens: []const lexer.Token) Self {
        return .{
            .allocator = allocator,
            .tokens = tokens,
        };
    }

    fn peek(self: @This()) lexer.Token {
        if (self.pos < self.tokens.len) return self.tokens[self.pos];
        return .eof;
    }

    fn next(self: *@This()) lexer.Token {
        const tok = self.peek();
        if (self.pos < self.tokens.len) self.pos += 1;
        return tok;
    }

    fn parse_primary(self: *@This(), diag: *Diagnostics) Error!*Expr {
        const tok = self.next();
        switch (tok) {
            .lparen => {
                const body = try self.parse_expr(diag);
                errdefer body.deinit(self.allocator, true);

                if (self.next() != .rparen) return Error.ExpectedRparen;

                return body;
            },
            .lambda => {
                const arg = self.next();
                if (arg != .identifier) return Error.ExpectedIdentifier;

                if (self.next() != .dot) return Error.ExpectedDot;

                const body = try self.parse(diag);
                errdefer body.deinit(self.allocator, true);

                const expr = try self.allocator.create(Expr);
                expr.* = .{
                    .function = .{
                        .arg = .{
                            .name = arg.identifier,
                        },
                        .expr = body,
                    },
                };

                return expr;
            },
            .identifier => |identifier| {
                const expr = try self.allocator.create(Expr);
                expr.* = .{
                    .variable = .{
                        .name = identifier,
                    },
                };

                return expr;
            },
            else => |other| {
                diag.message = try std.mem.print(&diag._message_buffer, "expected one of: `(`, `\\`, identifier, but found {s}", .{@tagName(other)});
                return Error.UnexpectedToken;
            },
        }
    }

    fn parse_expr(self: *@This(), diag: *Diagnostics) Error!*Expr {
        var expr = try parse_primary(self, diag);
        errdefer expr.deinit(self.allocator, true);

        while (true) {
            const token = self.peek();
            if (token == .rparen or token == .eof) break;

            const rhs = try parse_primary(self, diag);
            errdefer rhs.deinit(self.allocator, true);

            const app = try self.allocator.create(Expr);
            app.* = .{
                .application = .{
                    .lhs = expr,
                    .rhs = rhs,
                },
            };

            expr = app;
        }

        return expr;
    }

    pub const parse = parse_expr;
};

pub fn parse(allocator: std.mem.Allocator, diag: *Diagnostics, tokens: []const lexer.Token) Error!*Expr {
    var parser = Parser.init(allocator, tokens);
    const root = try parser.parse(diag);

    return root;
}

pub fn parse_quick(allocator: std.mem.Allocator, code: []const u8) !*Expr {
    var tokens = try lexer.tokenize(allocator, code);
    defer tokens.deinit(allocator);

    var diag: Diagnostics = .{};
    const root = parse(allocator, &diag, tokens.items) catch |e| {
        std.debug.print("parse fail: {s}", .{diag.message});
        return e;
    };

    return root;
}

test "Parse 1" {
    const allocator = std.testing.allocator;

    const root = try parse_quick(allocator, "(\\x.x) y");
    defer root.deinit(allocator, true);

    try std.testing.expectEqualStrings(root.application.lhs.function.arg.name, "x");
    try std.testing.expectEqualStrings(root.application.lhs.function.expr.variable.name, "x");
    try std.testing.expectEqualStrings(root.application.rhs.variable.name, "y");
}

test "Parse 2" {
    const allocator = std.testing.allocator;

    const root = try parse_quick(allocator, "(\\x.x) y x");
    defer root.deinit(allocator, true);

    try std.testing.expectEqualStrings("x", root.application.lhs.application.lhs.function.arg.name);
    try std.testing.expectEqualStrings("x", root.application.lhs.application.lhs.function.expr.variable.name);
    try std.testing.expectEqualStrings("y", root.application.lhs.application.rhs.variable.name);
    try std.testing.expectEqualStrings("x", root.application.rhs.variable.name);
}

test "Parse 3" {
    const allocator = std.testing.allocator;

    const root = try parse_quick(allocator, "(\\x.\\y.x) z");
    defer root.deinit(allocator, true);

    try std.testing.expectEqualStrings("x", root.application.lhs.function.arg.name);
    try std.testing.expectEqualStrings("y", root.application.lhs.function.expr.function.arg.name);
    try std.testing.expectEqualStrings("x", root.application.lhs.function.expr.function.expr.variable.name);
    try std.testing.expectEqualStrings("z", root.application.rhs.variable.name);
}
