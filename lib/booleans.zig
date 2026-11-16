const std = @import("std");
const Expr = @import("expr.zig").Expr;
const ExprFunction = @import("expr.zig").ExprFunction;
const parser = @import("parser.zig");

pub fn get_boolean_from_function(func: *ExprFunction) ?bool {
    if (func.expr.* != .function) return null;
    if (func.expr.function.expr.* != .variable) return null;

    const T = func.arg;
    const F = func.expr.function.arg;

    if (T.eq(F)) return null;

    const v = func.expr.function.expr.variable;
    if (v.eq(T)) return true;
    if (v.eq(F)) return false;

    return null;
}

pub fn get_boolean_from_expr(expr: *Expr) ?bool {
    if (expr.* != .function) return null;

    return get_boolean_from_function(&expr.function);
}

test "get_boolean_from_expr 0" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \T.\F.T
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(true, get_boolean_from_expr(expr));
}

test "get_boolean_from_expr 1" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \T.\F.F
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(false, get_boolean_from_expr(expr));
}

test "get_boolean_from_expr 2" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \T.\F.x
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(null, get_boolean_from_expr(expr));
}

test "get_boolean_from_expr 3" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \T.\F.F T
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(null, get_boolean_from_expr(expr));
}
