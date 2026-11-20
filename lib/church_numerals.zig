const std = @import("std");
const ExprFunction = @import("expr.zig").ExprFunction;
const Expr = @import("expr.zig").Expr;
const parser = @import("parser.zig");

pub fn get_church_numeral_from_function(func: *const ExprFunction) ?usize {
    if (func.expr.* != .function) return null;

    const f = func.arg;
    const x = func.expr.function.arg;

    var expr = func.expr.function.expr;
    var applications: usize = 0;

    while (true) {
        switch (expr.*) {
            .function => return null,
            .application => |*application| {
                if (application.lhs.* != .variable) return null;
                if (!application.lhs.variable.eq(f)) return null;

                applications += 1;
                expr = application.rhs;
            },
            .variable => |variable| {
                if (!variable.eq(x)) return null;
                break;
            },
        }
    }

    return applications;
}

pub fn get_church_numeral_from_expr(expr: *const Expr) ?usize {
    if (expr.* != .function) return null;

    return get_church_numeral_from_function(&expr.function);
}

test "get_church_numeral_from_expr 0" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \f.\x.f (f x)
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(2, get_church_numeral_from_expr(expr));
}

test "get_church_numeral_from_expr 1" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \f.\x.f (x x)
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(null, get_church_numeral_from_expr(expr));
}

test "get_church_numeral_from_expr 2" {
    const allocator = std.testing.allocator;

    const expr = try parser.parse_quick(allocator,
        \\ \f.\x.f (f f)
    );
    defer expr.deinit(allocator, true);

    try std.testing.expectEqual(null, get_church_numeral_from_expr(expr));
}
