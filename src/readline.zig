const std = @import("std");
const builtin = @import("builtin");

pub fn readline(allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    var buffer: [512]u8 = undefined;
    const stdin = std.Io.File.stdin();
    var reader = stdin.reader(io, &buffer);

    var input: std.ArrayList(u8) = .empty;

    while (true) {
        const ch = reader.interface.takeByte() catch |e| {
            if (e == std.Io.Reader.Error.EndOfStream) break;
            return e;
        };
        if (ch == '\n') break;

        try input.append(allocator, ch);
    }

    const slice = try allocator.dupe(u8, input.items);
    input.deinit(allocator);

    return slice;
}
