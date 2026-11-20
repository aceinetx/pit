const std = @import("std");

pub const expr = @import("./expr.zig");
pub const reduce = @import("./reduce.zig");
pub const lexer = @import("./lexer.zig");
pub const parser = @import("./parser.zig");
pub const church_numerals = @import("./church_numerals.zig");
pub const booleans = @import("./booleans.zig");
pub const tromp_diagrams = @import("./tromp_diagrams.zig");
pub const util = @import("./util.zig");

test {
    std.testing.refAllDecls(expr);
    std.testing.refAllDecls(reduce);
    std.testing.refAllDecls(lexer);
    std.testing.refAllDecls(parser);
    std.testing.refAllDecls(church_numerals);
    std.testing.refAllDecls(booleans);
    std.testing.refAllDecls(tromp_diagrams);
    std.testing.refAllDecls(util);
}
