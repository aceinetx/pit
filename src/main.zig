const std = @import("std");

const pit = @import("pit");
const readline = @import("readline.zig");

pub fn main(init: std.process.Init) !void {
    while (true) {
        const buffer = try readline.readline(init.gpa, init.io);
        defer init.gpa.free(buffer);

        if (std.mem.eql(u8, buffer, ":q")) {
            break;
        }

        std.log.info("{s}\n", .{buffer});

        var tokens = pit.lexer.tokenize(init.gpa, buffer) catch |e| {
            std.log.err("tokenize fail: {}", .{e});
            continue;
        };
        defer tokens.deinit(init.gpa);

        var diag: [256]u8 = @splat(0);
        const root = pit.parser.parse(init.gpa, &diag, tokens.items) catch |e| {
            std.log.err("parse fail: {}: {s}", .{ e, diag });
            continue;
        };
        defer root.deinit(init.gpa, true);

        pit.reduce.beta_reduce_all_the_way(init.gpa, root) catch |e| {
            std.log.err("beta reduction failed: {}", .{e});
            continue;
        };
        root.print(0);
    }
}
