const std = @import("std");

pub const TokenTag = enum {
    eof,
    identifier,
    lambda,
    dot,
    lparen,
    rparen,
};

pub const Token = union(enum) {
    eof: void,
    identifier: []const u8,
    lambda: void,
    dot: void,
    lparen: void,
    rparen: void,
};

pub const Error = error{InvalidToken} || std.mem.Allocator.Error;

inline fn is_identchar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn next(code: []const u8, pos: *usize) Error!Token {
    while (pos.* < code.len) {
        inline for (
            [_]struct { u8, Token }{
                .{ '\\', .lambda },
                .{ '.', .dot },
                .{ '(', .lparen },
                .{ ')', .rparen },
            },
        ) |pair| {
            if (pair.@"0" == code[pos.*]) {
                pos.* += 1;
                return pair.@"1";
            }
        }

        if (is_identchar(code[pos.*])) {
            const start = pos.*;

            while (pos.* < code.len and is_identchar(code[pos.*])) {
                pos.* += 1;
            }

            const end = pos.*;

            const slice = code[start..end];

            return .{ .identifier = slice };
        } else if (std.ascii.isWhitespace(code[pos.*])) {
            pos.* += 1;
        } else {
            return Error.InvalidToken;
        }
    }
    return .eof;
}

pub fn tokenize(allocator: std.mem.Allocator, code: []const u8) Error!std.ArrayList(Token) {
    var pos: usize = 0;
    var tokens = std.ArrayList(Token).empty;
    errdefer tokens.deinit(allocator);

    while (true) {
        const token = try next(code, &pos);
        if (token == .eof) break;

        try tokens.append(allocator, token);
    }

    return tokens;
}

test "Tokenize 1" {
    const allocator = std.testing.allocator;

    const code = "(\\x.x) x";
    var tokens = try tokenize(allocator, code);
    defer tokens.deinit(allocator);

    try std.testing.expect(tokens.items.len == 7);

    try std.testing.expect(tokens.items[0] == .lparen);
    try std.testing.expect(tokens.items[1] == .lambda);
    try std.testing.expect(std.mem.eql(u8, tokens.items[2].identifier, "x"));
    try std.testing.expect(tokens.items[3] == .dot);
    try std.testing.expect(std.mem.eql(u8, tokens.items[4].identifier, "x"));
    try std.testing.expect(tokens.items[5] == .rparen);
    try std.testing.expect(std.mem.eql(u8, tokens.items[6].identifier, "x"));
}
