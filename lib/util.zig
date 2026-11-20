const std = @import("std");
const expr = @import("./expr.zig");
const parser = @import("./parser.zig");

pub fn get_curried_input_variables_in_func(func: *expr.ExprFunction) usize {
    var count: usize = 0;

    var f = func;

    while (true) {
        count += 1;
        switch (f.expr.*) {
            .variable => break,
            .application => break,
            .function => |*inner| f = inner,
        }
    }

    return count;
}

pub fn get_curried_input_variables_in_expr(e: *expr.Expr) usize {
    if (e.* == .function)
        return get_curried_input_variables_in_func(&e.function)
    else
        return 0;
}

test {
    const allocator = std.testing.allocator;

    const f = try parser.parse_quick(allocator,
        \\ \a.\b.\c.a
    );
    defer f.deinit(allocator, true);

    const n = get_curried_input_variables_in_expr(f);
    try std.testing.expectEqual(3, n);
}

test {
    const allocator = std.testing.allocator;

    const f = try parser.parse_quick(allocator,
        \\ a
    );
    defer f.deinit(allocator, true);

    const n = get_curried_input_variables_in_expr(f);
    try std.testing.expectEqual(0, n);
}

test {
    const allocator = std.testing.allocator;

    const f = try parser.parse_quick(allocator,
        \\ \a.a
    );
    defer f.deinit(allocator, true);

    const n = get_curried_input_variables_in_expr(f);
    try std.testing.expectEqual(1, n);
}
