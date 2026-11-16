const std = @import("std");

const pit = @import("pit");
const console = @import("console.zig");

pub fn main(init: std.process.Init) !void {
    while (true) {
        console.print(init.io, "\\> ", .{});
        const buffer = try console.readline(init.gpa, init.io);
        defer init.gpa.free(buffer);

        if (std.mem.eql(u8, buffer, ":q")) {
            break;
        }

        var tokens = pit.lexer.tokenize(init.gpa, buffer) catch |e| {
            console.printn(init.io, "tokenize fail: {}", .{e});
            continue;
        };
        defer tokens.deinit(init.gpa);

        var diag: pit.parser.Diagnostics = .{};
        const expr = pit.parser.parse(init.gpa, &diag, tokens.items) catch |e| {
            console.printn(init.io, "parse fail: {}: {s}", .{ e, diag.message });
            continue;
        };
        defer expr.deinit(init.gpa, true);

        pit.reduce.beta_reduce_all_the_way(init.gpa, expr, .{}) catch |e| {
            console.printn(init.io, "beta reduction failed: {}", .{e});
            continue;
        };

        {
            var sb = std.ArrayList(u8).empty;
            defer sb.deinit(init.gpa);

            if (expr.display(init.gpa, &sb)) |_| {
                console.printn(init.io, "{s}", .{sb.items});
                if (pit.church_numerals.get_church_numeral_from_expr(expr)) |n| {
                    console.printn(init.io, "(church numeral: {})", .{n});
                }
                if (pit.booleans.get_boolean_from_expr(expr)) |b| {
                    console.printn(init.io, "(boolean: {})", .{b});
                }
            } else |_| {}
        }
    }
}
