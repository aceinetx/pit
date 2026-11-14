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

var output_buffer: [512]u8 = @splat(0);

pub fn print(io: std.Io, comptime fmt: []const u8, args: anytype) void {
    const stdout = std.Io.File.stdout();
    var writer = stdout.writer(io, &output_buffer);
    writer.interface.print(fmt, args) catch return;
    writer.interface.flush() catch {};
}

pub fn printn(io: std.Io, comptime fmt: []const u8, args: anytype) void {
    const stdout = std.Io.File.stdout();
    var writer = stdout.writer(io, &output_buffer);
    writer.interface.print(fmt, args) catch return;
    writer.interface.writeByte('\n') catch return;
    writer.interface.flush() catch {};
}
