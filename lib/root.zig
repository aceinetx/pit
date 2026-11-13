const std = @import("std");

pub const expr = @import("./expr.zig");
pub const reduce = @import("./reduce.zig");
pub const lexer = @import("./lexer.zig");
pub const parser = @import("./parser.zig");

test {
    std.testing.refAllDecls(expr);
    std.testing.refAllDecls(reduce);
    std.testing.refAllDecls(lexer);
    std.testing.refAllDecls(parser);
}
