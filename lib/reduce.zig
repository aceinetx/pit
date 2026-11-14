const std = @import("std");
const expr = @import("expr.zig");
const parser = @import("parser.zig");

fn expr_variable_available(ex: *expr.Expr, name: expr.ExprVariable) bool {
    switch (ex.*) {
        .variable => |*variable| {
            return variable.eq(name);
        },
        .function => |*function| {
            if (function.arg.eq(name)) return false;
            return expr_variable_available(function.expr, name);
        },
        .application => |*application| {
            if (expr_variable_available(application.lhs, name)) return true;
            if (expr_variable_available(application.rhs, name)) return true;
            return false;
        },
    }
}

fn replace(allocator: std.mem.Allocator, arg: expr.ExprVariable, body: *expr.Expr, with: *expr.Expr) !void {
    switch (body.*) {
        .variable => |*variable| {
            if (variable.eq(arg)) {
                const clone = try with.dupe(allocator);
                body.* = clone.*;

                allocator.destroy(clone);
            }
        },
        .function => |*function| {
            if (function.arg.eq(arg)) return;

            if (!expr_variable_available(function.expr, arg)) {
                return;
            }

            if (!expr_variable_available(with, function.arg)) {
                try replace(allocator, arg, function.expr, with);
                return;
            }

            const unambigous_name = try allocator.alloc(u8, function.arg.name.len + 1);
            errdefer allocator.free(unambigous_name);

            @memcpy(unambigous_name[0..function.arg.name.len], function.arg.name);
            unambigous_name[function.arg.name.len] = '\'';

            var variable: expr.Expr = .{
                .variable = .{
                    .name = unambigous_name,
                    .static = false,
                },
            };

            try replace(allocator, function.arg, function.expr, &variable);
            try replace(allocator, arg, function.expr, with);
            function.arg = try variable.variable.dupe(allocator);
        },
        .application => |*application| {
            try replace(allocator, arg, application.lhs, with);
            try replace(allocator, arg, application.rhs, with);
        },
    }
}

pub fn beta_reduce(allocator: std.mem.Allocator, ex: *expr.Expr) !bool {
    switch (ex.*) {
        .variable => {},
        .application => |*app| {
            if (app.lhs.* == .function) {
                const new = try app.lhs.function.expr.dupe(allocator);

                try replace(allocator, app.lhs.function.arg, new, app.rhs);

                app.deinit(allocator);

                ex.* = new.*;
                allocator.destroy(new);

                return true;
            }

            if (try beta_reduce(allocator, app.lhs)) return true;

            if (try beta_reduce(allocator, app.rhs)) return true;
        },
        .function => {
            return try beta_reduce(allocator, ex.function.expr);
        },
    }
    return false;
}

const BetaReduceAllTheWayOptions = struct {
    debug: bool = false,
    limit: usize = std.math.maxInt(usize),
};

pub fn beta_reduce_all_the_way(
    allocator: std.mem.Allocator,
    ex: *expr.Expr,
    opt: BetaReduceAllTheWayOptions,
) !void {
    if (opt.debug) {
        std.debug.print("BETA REDUCE ALL THE WAY\n", .{});
        ex.display_dump(allocator);
    }

    var reduces: usize = 0;

    while (reduces <= opt.limit) {
        if (!try beta_reduce(allocator, ex)) break;

        if (opt.debug) {
            std.debug.print("REDUCE\n", .{});
            ex.display_dump(allocator);
        }

        reduces += 1;
    }
}

test "Reduce 1" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.x) y
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y", root.variable.name);
}

test "Reduce 2" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x) z w
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("z", root.variable.name);
}

test "Reduce 3" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.x x) a
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("a", root.application.lhs.variable.name);
    try std.testing.expectEqualStrings("a", root.application.rhs.variable.name);
}

test "Reduce 4" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x) a
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y", root.function.arg.name);
    try std.testing.expectEqualStrings("a", root.function.expr.variable.name);
}

test "Reduce 5" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.x) ((\z.z) a)
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("a", root.variable.name);
}

test "Reduce 6 (Name collisions)" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x) y
    );
    // (\x.\y.x) y
    // (\y1.y)
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y", root.function.expr.variable.name);
}

test "Reduce 7 (Name collisions)" {
    // (\x.\y.x y) y
    // \y'.y y'

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x y) y
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y'", root.function.arg.name);
    try std.testing.expectEqualStrings("y", root.function.expr.application.lhs.variable.name);
    try std.testing.expectEqualStrings("y'", root.function.expr.application.rhs.variable.name);
}

test "Reduce 8 (Name collisions)" {
    // (\x.\y.y x) y
    // \y'.y' y

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.y x) y
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y'", root.function.arg.name);
    try std.testing.expectEqualStrings("y'", root.function.expr.application.lhs.variable.name);
    try std.testing.expectEqualStrings("y", root.function.expr.application.rhs.variable.name);
}

test "Reduce 9" {
    // (\x.\x.x) a
    // \x.x

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\x.x) a
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("x", root.function.arg.name);
    try std.testing.expectEqualStrings("x", root.function.expr.variable.name);
}

test "Reduce 10" {
    // (\x.\y.x) (\y.y)
    // \y.(\y.y)

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x) (\y.y)
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("y", root.function.arg.name);
    try std.testing.expectEqualStrings("y", root.function.expr.function.arg.name);
    try std.testing.expectEqualStrings("y", root.function.expr.function.expr.variable.name);
}

test "Reduce 11" {
    // ((\x.\y.x) a) b

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\((\x.\y.x) a) b
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("a", root.variable.name);
}

test "Reduce 12" {
    // (\f.f a) (\x.x)

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\f.f a) (\x.x)
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("a", root.variable.name);
}

test "Reduce 13" {
    // (\x.\y.x y) (\z.z) b

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x y) (\z.z) b
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("b", root.variable.name);
}

test "Reduce 14 (pair)" {
    // (\x.\y.x) z w
    // (\y.z) w
    // z

    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\(\x.\y.x) z w
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    try std.testing.expectEqualStrings("z", root.variable.name);
}

test "Reduce 15 (church numerals 0 + 1)" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\ (\n.\f.\x.f (n f x)) (\f.\x.x)
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    // (\f.\x.f x)
    try std.testing.expectEqualStrings("f", root.function.arg.name);
    try std.testing.expectEqualStrings("x", root.function.expr.function.arg.name);
    try std.testing.expectEqualStrings("f", root.function.expr.function.expr.application.lhs.variable.name);
    try std.testing.expectEqualStrings("x", root.function.expr.function.expr.application.rhs.variable.name);
}

test "Reduce 16 (church numerals 2 - 1)" {
    const allocator = std.testing.allocator;

    var root = try parser.parse_quick(allocator,
        \\ (\lhs.\rhs.rhs (\n.\f.\x.n (\g.\h.h (g f)) (\u.x) (\u.u)) lhs) ((\n.\f.\x.f (n f x)) ((\n.\f.\x.f (n f x)) (\f.\x.x))) ((\n.\f.\x.f (n f x)) (\f.\x.x))
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{});

    // (\f.\x.f x)

    root.dump(0);
    try std.testing.expectEqualStrings("f", root.function.arg.name);
    try std.testing.expectEqualStrings("x", root.function.expr.function.arg.name);
    try std.testing.expectEqualStrings("f", root.function.expr.function.expr.application.lhs.variable.name);
    try std.testing.expectEqualStrings("x", root.function.expr.function.expr.application.rhs.variable.name);
}

test "Reduce 17 (Y combinator countdown)" {
    const allocator = std.testing.allocator;

    // Y = \f.(\x.f (x x)) (\x.f (x x));
    // pred = \n.\f.\x.n (\g.\h.h (g f)) (\u.x) (\u.u);
    // iszero = \n.n (\_.false) true;
    // countdown = Y \rec.\n.(iszero n) (OK) (rec (pred n));

    var root = try parser.parse_quick(allocator,
        \\ (\f.(\x.f (x x)) (\x.f (x x))) (\r.\n.(\n.n (\_.\T.\F.F) (\T.\F.T)) n OK (r ((\n.\f.\x.n (\g.\h.h (g f)) (\u.x) (\u.u)) n))) ((\n.\f.\x.f (n f x)) ((\n.\f.\x.f (n f x)) (\f.\x.f x)))
    );
    defer root.deinit(allocator, true);

    try beta_reduce_all_the_way(allocator, root, .{ .debug = true });

    root.dump(0);
    try std.testing.expectEqualStrings("OK", root.variable.name);
}
